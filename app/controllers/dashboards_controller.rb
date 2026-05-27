class DashboardsController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    redirect_to(user_path(current_user)) and return if current_user.student?

    if current_user.admin?
      load_admin_dashboard
    else
      load_teacher_dashboard
    end
  end

  private

  def load_admin_dashboard
    @total_classroom_count = Classroom.count
    @total_teacher_count = User.teacher.count
    @total_student_count = User.student.count
    @pending_coupon_request_count = CouponUseRequest.pending.count
  end

  def load_teacher_dashboard
    @classrooms = policy_scope(Classroom).order(:name).load
    classroom_ids = @classrooms.map(&:id)

    @student_counts_by_classroom_id =
      ClassroomMembership.where(classroom_id: classroom_ids, role: "student").group(:classroom_id).count
    @today_compliment_counts_by_classroom_id =
      Compliment.where(classroom_id: classroom_ids, given_at: Time.current.all_day).group(:classroom_id).count
    @pending_coupon_request_counts_by_classroom_id =
      CouponUseRequest.pending.where(classroom_id: classroom_ids).group(:classroom_id).count

    message_enabled_classroom_ids = @classrooms.reject(&:messages_disabled?).map(&:id)
    @unread_student_message_counts_by_classroom_id =
      UserMessage.unread_student_messages.where(classroom_id: message_enabled_classroom_ids).group(:classroom_id).count
  end
end
