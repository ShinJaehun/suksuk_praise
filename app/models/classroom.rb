class Classroom < ApplicationRecord
    COMPLIMENT_KING_PERIODS = %w[daily weekly monthly].freeze
    MESSAGE_POLICIES = %w[disabled replies_only student_initiated].freeze

    has_secure_token :student_login_token

    belongs_to :school, optional: true

    # 교실 삭제 시 관련 칭찬/쿠폰도 함께 삭제
    has_many :classroom_memberships, dependent: :destroy
    has_many :users, through: :classroom_memberships
    has_many :user_coupons, dependent: :destroy
    has_many :compliments, dependent: :destroy

    def students
      users.merge(ClassroomMembership.where(role: "student", status: "active"))
    end

    def enabled_compliment_king_periods
      COMPLIMENT_KING_PERIODS.select do |period|
        public_send("#{period}_compliment_king_enabled?")
      end
    end

    validates :name, length: { maximum: 50 }
    validates :school, presence: true, if: -> { school_id.present? }
    validates :grade, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 6
    }, allow_nil: true
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
end
