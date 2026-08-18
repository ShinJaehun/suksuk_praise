class ApplicationController < ActionController::Base
  STUDENT_SESSION_TTL = 20.minutes

  include Pundit::Authorization
  include Pagy::Method

  helper_method :navigation_context
  
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :expire_inactive_teacher_session
  before_action :expire_student_session_if_inactive

  def after_sign_in_path_for(resource_or_scope)
    return user_path(resource_or_scope) if resource_or_scope.is_a?(User) && resource_or_scope.student?

    role_landing_path_for(resource_or_scope)
  end

  rescue_from Pundit::NotAuthorizedError do
    respond_to do |format|
      format.html do
        redirect_to(request.referrer.presence || root_path, alert: t("errors.not_authorized"))
      end
      format.json do
        render json: { ok: false, error: "not_authorized" }, status: :forbidden
      end
      format.any do
        head :forbidden
      end
    end
  end

  # 개발 시 권한 체크 누락 방지: index는 policy_scope, 그 외는 authorize 요구
  after_action :verify_authorized, unless: :skip_pundit_verify_authorized?
  after_action :verify_policy_scoped, if: :pundit_verify_policy_scoped?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :gender, :avatar_key])
  end


  private

  def navigation_context
    return {} unless request.format.html? && current_user
    return @navigation_context if defined?(@navigation_context)

    @navigation_context = { user: current_user }
    return @navigation_context unless current_user.active_teacher?

    school_membership = current_user.school_membership
    school = school_membership&.school
    active_school = school if school&.active?
    manager_membership =
      school_membership if active_school && school_membership.manager?

    @navigation_context.merge!(
      manager_membership: manager_membership,
      classrooms: manager_membership ? [] : teacher_nav_classrooms
    )
  end

  def teacher_nav_classrooms
    return [] unless current_user&.active_teacher?
    return @teacher_nav_classrooms if defined?(@teacher_nav_classrooms)

    @teacher_nav_classrooms = current_user.classroom_memberships.teacher
      .joins(classroom: :school)
      .merge(School.active)
      .includes(:classroom)
      .map(&:classroom)
  end

  def expire_inactive_teacher_session
    return unless current_user&.teacher? && current_user.inactive?

    sign_out(:user)
    redirect_to new_user_session_path, alert: t("devise.failure.inactive")
  end

  def broadcast_student_card_alerts_for(classroom, student)
    safely_broadcast_realtime(
      tag: :student_card_alerts,
      actor_id: current_user&.id,
      classroom_id: classroom.id,
      student_id: student.id
    ) do
      Turbo::StreamsChannel.broadcast_replace_to(
        classroom,
        :student_card_alerts,
        target: view_context.dom_id(student, :student_card_alerts),
        partial: "users/student_card_alerts",
        locals: {
          user: student,
          pending_coupon_request: pending_coupon_request_for?(classroom, student),
          unread_student_message: unread_student_message_for?(classroom, student),
          coupon_alert_path: student_card_coupon_alert_path(classroom, student),
          message_alert_path: student_card_message_alert_path(classroom, student)
        }
      )
    end
  end

  def safely_broadcast_realtime(tag:, **context)
    yield
  rescue StandardError => error
    app_location = error.backtrace_locations&.find do |location|
      location.absolute_path&.start_with?(Rails.root.to_s)
    end

    Rails.logger.warn(
      {
        event: "realtime_broadcast_failed",
        broadcast: tag,
        **context.compact,
        exception_class: error.class.name,
        app_backtrace: app_location&.to_s
      }
    )
  end

  def mark_unread_student_messages_read_for(classroom, student)
    UserMessage
      .unread_student_messages
      .where(classroom: classroom, sender: student)
      .update_all(read_at: Time.current, updated_at: Time.current)
  end

  def pending_coupon_request_for?(classroom, student)
    CouponUseRequest.pending.exists?(classroom: classroom, student: student)
  end

  def unread_student_message_for?(classroom, student)
    return false unless classroom.student_messages_enabled?

    UserMessage.unread_student_messages.exists?(classroom: classroom, sender: student)
  end

  def student_card_coupon_alert_path(classroom, student)
    classroom_student_path(classroom, student, anchor: view_context.dom_id(student, :coupons))
  end

  def student_card_message_alert_path(classroom, student)
    classroom_student_messages_path(classroom, student)
  end

  def expire_student_session_if_inactive
    return unless current_user&.student?
    return if student_session_ttl_exempt_controller?

    classroom_id = session[:student_login_classroom_id]
    if classroom_id.present? && !active_student_membership?(classroom_id)
      sign_out(:user)
      return redirect_to student_session_timeout_redirect_path(classroom_id),
        alert: "사용 시간이 지나 자동으로 로그아웃되었습니다. 다시 로그인해 주세요."
    end

    now = Time.current.to_i
    last_seen_at = session[:student_last_seen_at]

    unless last_seen_at.present?
      session[:student_last_seen_at] = now
      return
    end

    if now - last_seen_at.to_i > STUDENT_SESSION_TTL.to_i
      classroom_id = session[:student_login_classroom_id]
      sign_out(:user)
      redirect_to student_session_timeout_redirect_path(classroom_id),
        alert: "사용 시간이 지나 자동으로 로그아웃되었습니다. 다시 로그인해 주세요."
    else
      session[:student_last_seen_at] = now
    end
  end

  def active_student_membership?(classroom_id)
    ClassroomMembership.joins(classroom: :school).merge(School.active).exists?(
      classroom_id: classroom_id,
      user_id: current_user.id,
      role: "student",
      status: "active"
    )
  end

  def student_session_ttl_exempt_controller?
    devise_controller? || is_a?(StudentSessionsController)
  end

  def student_session_timeout_redirect_path(classroom_id)
    return new_student_session_path if classroom_id.blank?
    classroom = Classroom.find_by(id: classroom_id)
    return new_student_session_path unless classroom

    public_student_login_path(student_login_token: classroom.student_login_token)
  end

  def role_landing_path
    role_landing_path_for(current_user)
  end

  def role_landing_path_for(user)
    return user_path(user) if user.student?
    return schools_path if user.admin?

    managed_membership =
      if user.school_membership&.manager? && user.school_membership.school.active?
        user.school_membership
      end
    return school_path(managed_membership.school) if managed_membership

    regular_teacher_landing_path_for(user)
  end

  def regular_teacher_landing_path_for(user)
    classrooms = Classroom
      .joins(:school, :classroom_memberships)
      .merge(School.active)
      .where(classroom_memberships: { user_id: user.id, role: "teacher" })
      .distinct
      .order(:id)
      .limit(2)
      .to_a

    classrooms.one? ? classroom_path(classrooms.first) : classrooms_path
  end

  # index가 아닌 액션에서는 authorize 검증, Devise 컨트롤러는 제외
  def skip_pundit_verify_authorized?
    devise_controller? || action_name == "index"
  end

  # index 액션에서만 policy_scope 검증, Devise 컨트롤러는 제외
  def pundit_verify_policy_scoped?
    !devise_controller? && action_name == "index"
  end
end
