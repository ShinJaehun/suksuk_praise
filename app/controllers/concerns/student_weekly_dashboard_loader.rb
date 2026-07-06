module StudentWeeklyDashboardLoader
  extend ActiveSupport::Concern

  private

  def load_student_weekly_dashboard!(student:, classroom:)
    @week_offset = params[:week_offset].to_i
    week_start = Time.zone.today.beginning_of_week(:monday) + @week_offset.weeks
    weekdays = (0..4).map { |day_offset| week_start + day_offset.days }
    weekday_range = weekdays.first.beginning_of_day..weekdays.last.end_of_day
    @week_start = weekdays.first
    @week_end = weekdays.last

    compliment_counts_by_date =
      Compliment
        .where(classroom: classroom, receiver: student, given_at: weekday_range)
        .pluck(:given_at)
        .each_with_object(Hash.new(0)) { |given_at, counts| counts[given_at.to_date] += 1 }

    coupon_timestamps =
      UserCoupon
        .where(classroom: classroom, user: student)
        .where(
          "(issued_at BETWEEN :from AND :to) OR (used_at BETWEEN :from AND :to)",
          from: weekday_range.begin,
          to: weekday_range.end
        )
        .pluck(:issued_at, :used_at)
    issued_coupon_counts_by_date = Hash.new(0)
    used_coupon_counts_by_date = Hash.new(0)

    coupon_timestamps.each do |issued_at, used_at|
      issued_coupon_counts_by_date[issued_at.to_date] += 1 if weekday_range.cover?(issued_at)
      used_coupon_counts_by_date[used_at.to_date] += 1 if used_at && weekday_range.cover?(used_at)
    end

    @weekly_activity = weekdays.zip(%w[월 화 수 목 금]).map do |date, label|
      {
        date: date,
        label: label,
        praise_count: compliment_counts_by_date[date],
        issued_coupon_count: issued_coupon_counts_by_date[date],
        used_coupon_count: used_coupon_counts_by_date[date]
      }
    end

    prepare_student_dashboard_graph!(compliment_counts_by_date)

    weekly_praise_count = compliment_counts_by_date.values.sum
    weekly_issued_coupon_count = issued_coupon_counts_by_date.values.sum
    weekly_used_coupon_count = used_coupon_counts_by_date.values.sum

    @student_dashboard_summary = {
      total_praise_count: Compliment.where(classroom: classroom, receiver: student).count,
      weekly_praise_count: weekly_praise_count,
      held_coupon_count: UserCoupon.issued.where(classroom: classroom, user: student).count,
      weekly_issued_coupon_count: weekly_issued_coupon_count,
      weekly_used_coupon_count: weekly_used_coupon_count
    }
    @weekly_activity_empty =
      weekly_praise_count.zero? &&
      weekly_issued_coupon_count.zero? &&
      weekly_used_coupon_count.zero?
  end

  def prepare_student_dashboard_graph!(compliment_counts_by_date)
    weekly_praise_max = compliment_counts_by_date.values.max.to_i
    raw_tick_step = [weekly_praise_max.fdiv(4), 1].max
    magnitude = 10**Math.log10(raw_tick_step).floor
    normalized_tick_step = raw_tick_step.fdiv(magnitude)
    nice_multiplier =
      if normalized_tick_step <= 1
        1
      elsif normalized_tick_step <= 2
        2
      elsif normalized_tick_step <= 5
        5
      else
        10
      end
    y_axis_tick_step = nice_multiplier * magnitude
    @y_axis_max = y_axis_tick_step * 4
    @y_axis_ticks = (0..4).map do |index|
      value = index * y_axis_tick_step
      { value: value, y: 115 - (index * 20) }
    end
    @weekly_activity.each_with_index do |activity, index|
      activity[:x] = 50 + (index * 100)
      activity[:y] = 115 - (activity[:praise_count].fdiv(@y_axis_max) * 80).round
    end

    first_point = @weekly_activity.first
    curve_segments = @weekly_activity.each_cons(2).map do |start_point, end_point|
      midpoint_x = (start_point[:x] + end_point[:x]) / 2
      "C #{midpoint_x} #{start_point[:y]}, #{midpoint_x} #{end_point[:y]}, #{end_point[:x]} #{end_point[:y]}"
    end
    @weekly_praise_path = ["M #{first_point[:x]} #{first_point[:y]}", *curve_segments].join(" ")
  end
end
