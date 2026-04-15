class Users::RegistrationsController < Devise::RegistrationsController
  before_action :authenticate_scope!, only: [:edit_password, :update_password]

  def edit
    self.resource = current_user
  end

  def edit_password
    self.resource = current_user
    clean_up_passwords(resource)
    set_minimum_password_length

    render :edit_password, layout: false
  end

  def update_password
    self.resource = current_user

    if resource.update_with_password(password_update_params)
      bypass_sign_in(resource, scope: resource_name)
      flash.now[:notice] = "비밀번호를 변경했습니다."
      render :update_password, formats: :turbo_stream
    else
      clean_up_passwords(resource)
      set_minimum_password_length
      render :edit_password, formats: :html, layout: false, status: :unprocessable_entity
    end
  end

  protected

  def update_resource(resource, params)
    return super if password_change_params?(params)

    params.delete(:current_password)
    resource.update_without_password(params)
  end

  def after_update_path_for(resource)
    user_path(resource)
  end

  private

  def password_change_params?(params)
    params[:password].present? || params[:password_confirmation].present?
  end

  def password_update_params
    params.require(resource_name).permit(:password, :password_confirmation, :current_password)
  end
end
