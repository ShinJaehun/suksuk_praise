class HomeController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    redirect_to(new_user_session_path) and return unless user_signed_in?

    redirect_to(current_user.student? ? user_path(current_user) : classrooms_path)
  end
end
