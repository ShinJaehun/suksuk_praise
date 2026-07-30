# app/controllers/classrooms_controller.rb
require "set"

class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_students_to_mypage!, only: [:index, :show]
  before_action :set_classroom, only: [
    :show, :destroy
  ]

  def index
    # index는 policy_scope만 요구(verify_policy_scoped 훅 통과)
    prepare_school_filter if current_user.admin?
    classrooms_scope = policy_scope(Classroom).joins(:school).merge(School.active)
    classrooms_scope = classrooms_scope.where(school_id: @selected_school.id) if current_user.admin? && @selected_school
    context = Classrooms::IndexContext.new(classrooms_scope: classrooms_scope)
    @classrooms = context.classrooms
    @classrooms_index_title = t(classrooms_index_title_key)
    classroom_ids = @classrooms.map(&:id)
    @classroom_teacher_counts = context.teacher_counts
    @classroom_teacher_previews = context.teacher_previews
    @classroom_student_counts = context.student_counts
    @classroom_student_previews = context.student_previews
    assigned_classroom_ids =
      if current_user.active_teacher?
        current_user.classroom_memberships
          .where(role: "teacher", classroom_id: classroom_ids)
          .pluck(:classroom_id)
          .to_set
      else
        Set.new
      end
    @manageable_classroom_ids =
      if current_user.admin?
        classroom_ids.to_set
      elsif current_user_school_manager?
        classroom_ids.to_set
      elsif current_user.active_teacher?
        assigned_classroom_ids
      else
        Set.new
      end
    @member_manageable_classroom_ids =
      if current_user.admin?
        classroom_ids.to_set
      elsif current_user.active_teacher?
        assigned_classroom_ids
      else
        Set.new
      end
    # authorize Classroom  # <- 불필요 (after_action에서 index는 verify_authorized 제외)
  end

  def show
    authorize @classroom
    @can_manage_classroom = policy(@classroom).update?
    @can_manage_classroom_members = policy(@classroom).manage_members?
    @can_refresh_compliment_king = policy(@classroom).refresh_compliment_king?
    can_create_compliment = policy(@classroom).create_compliment?
    context = Classrooms::ShowContext.new(
      classroom: @classroom,
      current_user: current_user,
      include_student_alerts: @can_manage_classroom,
      include_compliment_presets: can_create_compliment
    )
    @student_memberships = context.student_memberships
    @students = context.students
    @homeroom_teachers = context.homeroom_teachers
    @enabled_compliment_king_periods = context.enabled_compliment_king_periods
    @refreshable_compliment_king_periods = context.refreshable_compliment_king_periods
    @compliment_king_period_cards = context.compliment_king_period_cards
    @student_ids_with_pending_coupon_use_requests = context.pending_coupon_use_request_student_ids
    @student_ids_with_unread_student_messages = context.unread_student_message_student_ids
    @active_compliment_presets = context.active_compliment_presets
    @today_compliment_counts_by_student_id = context.today_compliment_counts_by_student_id
  end

  def new
    authorize Classroom
    @classroom = Classroom.new
    assign_manager_school
    prepare_classroom_form
  end

  def create
    authorize Classroom
    @classroom = Classroom.new
    assign_manager_school
    @classroom.assign_attributes(classroom_params)

    if @classroom.school&.inactive?
      @classroom.errors.add(:school, t("school_status.inactive_school"))
      prepare_classroom_form
      render :new, status: :unprocessable_entity
    elsif @classroom.save
      redirect_to classroom_path(@classroom), notice: t("classrooms.create.success")
    else
      prepare_classroom_form
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @classroom

    if @classroom.destroy
      redirect_to classrooms_path,
        notice: t("classrooms.destroy.success"),
        status: :see_other
    else
      redirect_to edit_classroom_path(@classroom),
        alert: classroom_destroy_error_message,
        status: :see_other
    end
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
    redirect_to edit_classroom_path(@classroom),
      alert: t("classrooms.destroy.failure"),
      status: :see_other
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def classroom_destroy_error_message
    @classroom.errors.full_messages.to_sentence.presence || t("classrooms.destroy.failure")
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
    return false unless defined?(@classroom) && @classroom.present?

    policy(@classroom).manage_operations?
  end

  def structure_settings_allowed?
    return false unless defined?(@classroom) && @classroom.present?

    policy(@classroom).manage_structure?
  end

  def load_school_options
    @school_options = policy_scope(School).active.order(:name, :id)
  end

  def prepare_classroom_form
    load_school_options if current_user.admin?
  end

  def current_user_school_manager?
    current_user&.active_teacher? &&
      current_user.school_membership&.manager? &&
      current_user.school_membership.school.active?
  end

  def prepare_school_filter
    @filter_schools = policy_scope(School).active.order(:name, :id).load
    @selected_school = @filter_schools.detect { |school| school.id == school_filter_id }
  end

  def school_filter_id
    value = params[:school_id].to_s
    return nil unless value.match?(/\A[1-9]\d*\z/)

    value.to_i
  end

  def assign_manager_school
    return unless current_user_school_manager?

    @classroom.school = current_user.school_membership.school
  end

  def redirect_students_to_mypage!
    return unless current_user&.student?

    redirect_to user_path(current_user)
  end

  def classrooms_index_title_key
    return "classrooms.index.admin_title" if current_user.admin?
    return "classrooms.index.manager_title" if current_user_school_manager?

    "classrooms.index.teacher_title"
  end

end
