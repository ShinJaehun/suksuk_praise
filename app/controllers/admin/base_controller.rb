class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  
  layout "application"

  private

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: t("errors.admin_only")
    end
  end
end
