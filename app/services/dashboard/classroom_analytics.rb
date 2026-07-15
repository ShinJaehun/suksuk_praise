module Dashboard
  class ClassroomAnalytics
    Result = Struct.new(:student_rows, :summary, keyword_init: true)

    METRIC_KEYS = {
      "compliments" => :compliments_count,
      "issued" => :issued_count,
      "used" => :used_count
    }.freeze

    def self.call(classroom:, time_range:, metric:)
      new(classroom:, time_range:, metric:).call
    end

    def initialize(classroom:, time_range:, metric:)
      @classroom = classroom
      @time_range = time_range
      @metric_key = METRIC_KEYS.fetch(metric)
    end

    def call
      memberships = classroom.classroom_memberships
        .student
        .active
        .includes(user: { avatar_attachment: :blob })
        .order(:created_at, :id)
        .load
      student_ids = memberships.map(&:user_id)

      compliments = compliment_counts(student_ids)
      issued = coupon_event_counts(student_ids, "issued")
      used = coupon_event_counts(student_ids, "used")

      rows = memberships.map do |membership|
        {
          student: membership.user,
          compliments_count: compliments.fetch(membership.user_id, 0),
          issued_count: issued.fetch(membership.user_id, 0),
          used_count: used.fetch(membership.user_id, 0)
        }
      end

      add_metric_values!(rows)

      Result.new(
        student_rows: rows,
        summary: {
          compliments_count: rows.sum { |row| row[:compliments_count] },
          issued_count: rows.sum { |row| row[:issued_count] },
          used_count: rows.sum { |row| row[:used_count] },
          zero_compliment_students_count: rows.count { |row| row[:compliments_count].zero? }
        }
      )
    end

    private

    attr_reader :classroom, :time_range, :metric_key

    def compliment_counts(student_ids)
      return {} if student_ids.empty?

      Compliment
        .where(classroom_id: classroom.id, receiver_id: student_ids, given_at: time_range)
        .group(:receiver_id)
        .count
    end

    def coupon_event_counts(student_ids, action)
      return {} if student_ids.empty?

      CouponEvent
        .joins(:user_coupon)
        .where(
          coupon_events: { classroom_id: classroom.id, action: action, created_at: time_range },
          user_coupons: { user_id: student_ids }
        )
        .group("user_coupons.user_id")
        .count
    end

    def add_metric_values!(rows)
      maximum = rows.map { |row| row.fetch(metric_key) }.max.to_i

      rows.each do |row|
        count = row.fetch(metric_key)
        row[:selected_metric_count] = count
        row[:bar_percent] = maximum.zero? ? 0 : (count.fdiv(maximum) * 100).round
      end
    end
  end
end
