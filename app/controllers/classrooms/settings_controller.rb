class Classrooms::SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom

  def edit
    authorize @classroom
    render "classrooms/edit"
  end

  def update
    authorize @classroom

    if school_change_attempt?
      render "classrooms/edit", status: :unprocessable_content
    elsif @classroom.update(classroom_params)
      redirect_to @classroom, notice: t("classrooms.update.success")
    else
      render "classrooms/edit", status: :unprocessable_content
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def classroom_params
    permitted = []
    permitted.concat(%i[name grade]) if structure_settings_allowed?
    permitted.concat(operation_setting_attributes) if operation_settings_allowed?

    params.require(:classroom).permit(*permitted.uniq)
  end

  def operation_setting_attributes
    %i[
      daily_compliment_king_enabled
      weekly_compliment_king_enabled
      monthly_compliment_king_enabled
      message_policy
    ]
  end

  def operation_settings_allowed?
    policy(@classroom).manage_operations?
  end

  def structure_settings_allowed?
    policy(@classroom).manage_structure?
  end

  def school_change_attempt?
    return false unless structure_settings_allowed?
    return false unless params.require(:classroom).key?(:school_id)
    return false if params.dig(:classroom, :school_id).to_s == @classroom.school_id.to_s

    @classroom.errors.add(:school, :immutable)
    true
  end
end
