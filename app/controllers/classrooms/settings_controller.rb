class Classrooms::SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom

  def edit
    authorize @classroom
    prepare_classroom_form
    render "classrooms/edit"
  end

  def update
    authorize @classroom

    if inactive_target_school? || manager_school_change_attempt? || teacher_school_assignment_conflict?
      prepare_classroom_form
      render "classrooms/edit", status: :unprocessable_entity
    elsif @classroom.update(classroom_params)
      redirect_to @classroom, notice: t("classrooms.update.success")
    else
      prepare_classroom_form
      render "classrooms/edit", status: :unprocessable_entity
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
    permitted << :school_id if current_user.admin?

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

  def prepare_classroom_form
    @school_options = policy_scope(School).active.order(:name, :id) if current_user.admin?
  end

  def teacher_school_assignment_conflict?
    return false unless current_user.admin?

    target_school_id = params.dig(:classroom, :school_id).presence
    return false if target_school_id.blank? || target_school_id.to_s == @classroom.school_id.to_s

    teacher_ids = @classroom.classroom_memberships
      .teacher
      .joins(:user)
      .where(users: { role: "teacher" })
      .pluck(:user_id)

    conflict = SchoolMembership.where(user_id: teacher_ids, school_id: target_school_id).count != teacher_ids.size
    if conflict
      @classroom.errors.add(:base, t("classrooms.errors.teacher_school_required"))
    end
    conflict
  end

  def manager_school_change_attempt?
    return false unless current_user_school_manager?
    return false unless params.require(:classroom).key?(:school_id)
    return false if params.dig(:classroom, :school_id).to_s == @classroom.school_id.to_s

    @classroom.errors.add(:base, t("classrooms.errors.manager_school_change"))
    true
  end

  def inactive_target_school?
    return false unless current_user.admin?

    target_school_id = params.dig(:classroom, :school_id).presence
    return false if target_school_id.blank?
    return false if School.active.exists?(id: target_school_id)

    @classroom.errors.add(:school, t("school_status.inactive_school"))
    true
  end

  def current_user_school_manager?
    current_user&.active_teacher? &&
      current_user.school_membership&.manager? &&
      current_user.school_membership.school.active?
  end
end
