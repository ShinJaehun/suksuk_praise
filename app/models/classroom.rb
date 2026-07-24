class Classroom < ApplicationRecord
    MAX_ACTIVE_STUDENTS = 30
    COMPLIMENT_KING_PERIODS = %w[daily weekly monthly].freeze
    MESSAGE_POLICIES = %w[disabled replies_only student_initiated].freeze

    has_secure_token :student_login_token

    belongs_to :school

    # Empty classrooms may remove their remaining teacher memberships on deletion.
    # Operational records are protected by the prepended destroy guard below.
    has_many :classroom_memberships, dependent: :destroy
    has_many :users, through: :classroom_memberships
    has_many :user_coupons, dependent: :destroy
    has_many :compliments, dependent: :destroy
    has_many :coupon_events
    has_many :user_messages

    before_destroy :prevent_destroy_with_students_or_history, prepend: true

    def students
      users.merge(ClassroomMembership.where(role: "student", status: "active"))
    end

    def self.accessible_for_compliments(user)
      return none unless user
      return all if user.admin?
      return none unless user.teacher?

      joins(:classroom_memberships)
        .where(classroom_memberships: { user_id: user.id, role: "teacher", status: "active" })
        .distinct
    end

    def active_student_memberships_count
      classroom_memberships.student.active.count
    end

    def enabled_compliment_king_periods
      COMPLIMENT_KING_PERIODS.select { |period| compliment_king_enabled_for?(period) }
    end

    def compliment_king_enabled_for?(period)
      return false unless COMPLIMENT_KING_PERIODS.include?(period.to_s)

      public_send("#{period}_compliment_king_enabled?")
    end

    def compliment_king_refresh_available_for?(period, date: Time.zone.today)
      period = period.to_s
      date = date.to_date
      return false unless COMPLIMENT_KING_PERIODS.include?(period)
      return true if period == "daily"
      return true if school.blank?

      calendar = SchoolCalendar.new(school)
      case period
      when "weekly"
        calendar.last_school_day_of_week(date) == date
      when "monthly"
        calendar.last_school_day_of_month(date) == date
      else
        false
      end
    end

    validates :name, length: { maximum: 50 }
    validates :grade, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 6
    }
    validates :message_policy, inclusion: { in: MESSAGE_POLICIES }

    def messages_disabled?
      message_policy == "disabled"
    end

    def replies_only_messages?
      message_policy == "replies_only"
    end

    def student_initiated_messages?
      message_policy == "student_initiated"
    end

    def student_messages_enabled?
      !messages_disabled?
    end

    def student_can_start_messages?
      student_initiated_messages?
    end

    def destroyable_without_history?
      !classroom_memberships.student.exists? &&
        !compliments.exists? &&
        !user_coupons.exists? &&
        !coupon_events.exists? &&
        !user_messages.exists?
    end

    private

    def prevent_destroy_with_students_or_history
      return if destroyable_without_history?

      errors.add(:base, :students_or_history_present)
      throw :abort
    end
end
