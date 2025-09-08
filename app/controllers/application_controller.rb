class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError do
    redirect_to(request.referrer.presence || root_path, alert: "권한이 없습니다.")
  end
end