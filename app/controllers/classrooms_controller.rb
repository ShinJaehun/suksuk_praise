# app/controllers/classrooms_controller.rb
require "set"

class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_students_to_mypage!, only: [:index, :show]
  before_action :set_classroom, only: [
    :show, :edit, :update, :destroy
  ]

  def index
    # index는 policy_scope만 요구(verify_policy_scoped 훅 통과)
    prepare_school_filter if current_user.admin?
    classrooms_scope = policy_scope(Classroom).joins(:school).merge(School.active)
    classrooms_scope = classrooms_scope.where(school_id: @selected_school.id) if current_user.admin? && @selected_school
    @classrooms = classrooms_scope.includes(:school).order(created_at: :desc)
    @classrooms_index_title = t(classrooms_index_title_key)
    classroom_ids = @classrooms.map(&:id)
    teacher_memberships = ClassroomMembership
      .joins(:user)
      .where(classroom_id: classroom_ids, role: "teacher", users: { role: "teacher", active: true })
    @classroom_teacher_counts = teacher_memberships.group(:classroom_id).count
    @classroom_teacher_previews = classroom_membership_previews(
      classroom_ids,
      role: "teacher",
      user_role: "teacher",
      limit_per_classroom: 3
    )
    @classroom_student_counts = ClassroomMembership
      .where(classroom_id: classroom_ids, role: "student", status: "active")
      .group(:classroom_id)
      .count
    @classroom_student_previews = classroom_membership_previews(
      classroom_ids,
      role: "student",
      status: "active",
      limit_per_classroom: 5
    )
    @manageable_classroom_ids =
      if current_user.admin?
        classroom_ids.to_set
      elsif current_user_school_manager?
        classroom_ids.to_set
      elsif current_user.active_teacher?
        current_user.classroom_memberships
          .where(role: "teacher", classroom_id: classroom_ids)
          .pluck(:classroom_id)
          .to_set
      else
        Set.new
      end
    @member_manageable_classroom_ids =
      if current_user.admin?
        classroom_ids.to_set
      elsif current_user.active_teacher?
        current_user.classroom_memberships
          .where(role: "teacher", classroom_id: classroom_ids)
          .pluck(:classroom_id)
          .to_set
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

  def edit
    authorize @classroom
    prepare_classroom_form
  end

  def update
    authorize @classroom

    if inactive_target_school? || manager_school_change_attempt? || teacher_school_assignment_conflict?
      prepare_classroom_form
      render :edit, status: :unprocessable_entity
    elsif @classroom.update(classroom_params)
      redirect_to @classroom, notice: t("classrooms.update.success")
    else
      prepare_classroom_form
      render :edit, status: :unprocessable_entity
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

  def redirect_students_to_mypage!
    return unless current_user&.student?

    redirect_to user_path(current_user)
  end

  def classroom_membership_previews(classroom_ids, role:, limit_per_classroom:, user_role: nil, status: nil)
    return {} if classroom_ids.empty?

    membership_scope = ClassroomMembership.where(classroom_id: classroom_ids, role: role)
    membership_scope = membership_scope.where(status: status) if status
    membership_scope = membership_scope.joins(:user).where(users: { role: user_role }) if user_role
    membership_scope = membership_scope.where(users: { active: true }) if user_role == "teacher"

    ranked_membership_ids = ClassroomMembership
      .from(
        membership_scope
          .select(
            "classroom_memberships.id, classroom_memberships.classroom_id, " \
            "ROW_NUMBER() OVER (PARTITION BY classroom_memberships.classroom_id " \
            "ORDER BY classroom_memberships.created_at ASC, classroom_memberships.id ASC) AS preview_position"
          ),
        :classroom_memberships
      )
      .where("preview_position <= ?", limit_per_classroom)
      .pluck(:id)

    ClassroomMembership
      .where(id: ranked_membership_ids)
      .includes(user: { avatar_attachment: :blob })
      .order(:classroom_id, :created_at, :id)
      .group_by(&:classroom_id)
      .transform_values { |memberships| memberships.map(&:user) }
  end

  def classrooms_index_title_key
    return "classrooms.index.admin_title" if current_user.admin?
    return "classrooms.index.manager_title" if current_user_school_manager?

    "classrooms.index.teacher_title"
  end

end
