class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method
  
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError do
    redirect_to(request.referrer.presence || root_path, alert: t("errors.not_authorized"))
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

  # index가 아닌 액션에서는 authorize 검증, Devise 컨트롤러는 제외
  def skip_pundit_verify_authorized?
    devise_controller? || action_name == "index"
  end

  # index 액션에서만 policy_scope 검증, Devise 컨트롤러는 제외
  def pundit_verify_policy_scoped?
    !devise_controller? && action_name == "index"
  end
end