class Users::RegistrationsController < Devise::RegistrationsController
  before_action :redirect_student_self_account_edit!, only: [:edit, :update, :edit_password, :update_password]
  before_action :set_account_avatar_keys, only: [:edit, :update]
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
    filter_account_avatar_params!(resource, params)
    resource.update_without_password(params)
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end

  private

  def redirect_student_self_account_edit!
    return unless current_user&.student?

    redirect_to user_path(current_user), alert: "학생 계정 정보는 선생님에게 요청해 주세요. PIN은 PIN 변경 페이지에서 바꿀 수 있습니다."
  end

  def set_account_avatar_keys
    @account_avatar_keys = account_avatar_keys_for(current_user).select { |avatar_key| helpers.avatar_asset_key?(avatar_key) }
  end

  def filter_account_avatar_params!(user, params)
    if params[:avatar_key].present? && !account_avatar_keys_for(user).include?(params[:avatar_key])
      params.delete(:avatar_key)
    end

    params.delete(:gender) unless (user.teacher? || user.admin?) && %w[male female].include?(params[:gender])
  end

  def account_avatar_keys_for(user)
    return User::TEACHER_MALE_AVATAR_KEYS + User::TEACHER_FEMALE_AVATAR_KEYS if user&.teacher? || user&.admin?

    []
  end

  def password_change_params?(params)
    params[:password].present? || params[:password_confirmation].present?
  end

  def password_update_params
    params.require(resource_name).permit(:password, :password_confirmation, :current_password)
  end
end
