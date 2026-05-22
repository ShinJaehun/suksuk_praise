class StudentPinsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_student!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def edit
  end

  def update
    if current_pin_valid? && new_pin_valid? && new_pin_confirmed?
      current_user.update!(student_pin: new_pin)
      redirect_to user_path(current_user), notice: "PIN을 변경했습니다."
    else
      flash.now[:alert] = error_message
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_student!
    return if current_user&.student?

    redirect_to root_path, alert: t("errors.not_authorized")
  end

  def current_pin_valid?
    current_user.student_pin_configured? &&
      current_user.authenticate_student_pin(params[:current_pin].to_s)
  end

  def new_pin_valid?
    new_pin.match?(/\A\d{4}\z/)
  end

  def new_pin_confirmed?
    new_pin == params[:student_pin_confirmation].to_s
  end

  def new_pin
    params[:student_pin].to_s
  end

  def error_message
    return "현재 PIN을 확인해 주세요." unless current_pin_valid?
    return "새 PIN은 4자리 숫자여야 합니다." unless new_pin_valid?
    return "새 PIN 확인이 일치하지 않습니다." unless new_pin_confirmed?

    "PIN을 변경할 수 없습니다."
  end
end
