class DashboardsController < ApplicationController
  include StudentWeeklyDashboardLoader

  before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    if current_user.student?
      load_student_dashboard
    elsif current_user.admin?
      load_admin_dashboard
    else
      load_teacher_dashboard
    end
  end

  private

  def load_student_dashboard
    classroom_id = session[:student_login_classroom_id]
    membership = current_user.classroom_memberships.active.student.includes(:classroom).find_by(classroom_id: classroom_id)

    unless membership
      sign_out(:user)
      return redirect_to student_session_timeout_redirect_path(classroom_id),
        alert: "사용 시간이 지나 자동으로 로그아웃되었습니다. 다시 로그인해 주세요."
    end

    @classroom = membership.classroom
    load_student_weekly_dashboard!(student: current_user, classroom: @classroom)
  end

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
