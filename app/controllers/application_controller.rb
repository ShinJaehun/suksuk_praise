class ApplicationController < ActionController::Base
  STUDENT_SESSION_TTL = 20.minutes

  include Pundit::Authorization
  include Pagy::Method
  
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :expire_student_session_if_inactive

  def after_sign_in_path_for(resource_or_scope)
    return user_path(resource_or_scope) if resource_or_scope.is_a?(User) && resource_or_scope.student?

    super
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
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end


  private

  def broadcast_student_card_alerts_for(classroom, student)
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
    UserMessage.unread_student_messages.exists?(classroom: classroom, sender: student)
  end

  def student_card_coupon_alert_path(classroom, student)
    classroom_student_path(classroom, student, anchor: view_context.dom_id(student, :coupons))
  end

  def student_card_message_alert_path(classroom, student)
    classroom_student_path(classroom, student, anchor: view_context.dom_id(student, :message_section))
  end

  def expire_student_session_if_inactive
    return unless current_user&.student?
    return if student_session_ttl_exempt_controller?

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

  def student_session_ttl_exempt_controller?
    devise_controller? || is_a?(StudentSessionsController)
  end

  def student_session_timeout_redirect_path(classroom_id)
    return new_student_session_path if classroom_id.blank?
    return new_student_session_path unless Classroom.exists?(id: classroom_id)

    classroom_student_login_path(classroom_id)
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
