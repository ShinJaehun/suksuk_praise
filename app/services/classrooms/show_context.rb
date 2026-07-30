require "set"

class Classrooms::ShowContext
  def initialize(classroom:, current_user:, include_student_alerts:, include_compliment_presets:)
    @classroom = classroom
    @current_user = current_user
    @include_student_alerts = include_student_alerts
    @include_compliment_presets = include_compliment_presets
  end

  def student_memberships
    @student_memberships ||= @classroom.classroom_memberships
      .student
      .active
      .in_roster_order
      .preload(user: { avatar_attachment: :blob })
  end

  def students
    @students ||= User.where(id: student_memberships.map(&:user_id))
  end

  def homeroom_teachers
    @homeroom_teachers ||= User.teacher.active
      .joins(:classroom_memberships)
      .where(classroom_memberships: { classroom_id: @classroom.id, role: "teacher" })
      .with_attached_avatar
      .order(:name, :id)
  end

  def enabled_compliment_king_periods
    @enabled_compliment_king_periods ||= @classroom.enabled_compliment_king_periods
  end

  def refreshable_compliment_king_periods
    @refreshable_compliment_king_periods ||= enabled_compliment_king_periods.select do |period|
      @classroom.compliment_king_refresh_available_for?(period)
    end
  end

  def compliment_king_period_cards
    @compliment_king_period_cards ||= enabled_compliment_king_periods.map do |period|
      {
        period: period,
        frame_id: ActionView::RecordIdentifier.dom_id(@classroom, :"compliment_king_#{period}")
      }
    end
  end

  def pending_coupon_use_request_student_ids
    return Set.new unless @include_student_alerts

    @pending_coupon_use_request_student_ids ||= Set.new(CouponUseRequest
      .pending
      .where(classroom_id: @classroom.id, student_id: students.select(:id))
      .distinct
      .pluck(:student_id))
  end

  def unread_student_message_student_ids
    return Set.new unless @include_student_alerts
    return Set.new unless @classroom.student_messages_enabled?

    @unread_student_message_student_ids ||= Set.new(UserMessage
      .unread_student_messages
      .where(classroom_id: @classroom.id, sender_id: students.select(:id))
      .distinct
      .pluck(:sender_id))
  end

  def active_compliment_presets
    return unless @include_compliment_presets

    @active_compliment_presets ||= @current_user.compliment_presets.active.ordered
  end

  def today_compliment_counts_by_student_id
    @today_compliment_counts_by_student_id ||= Compliment
      .where(
        classroom_id: @classroom.id,
        receiver_id: students.select(:id),
        given_at: Time.zone.today.all_day
      )
      .group(:receiver_id)
      .count
  end
end
