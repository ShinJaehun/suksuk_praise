class Schools::TeachersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_school
  before_action :authorize_school_teacher_management
  before_action :set_teacher, only: %i[edit update deactivate reactivate]

  layout -> { turbo_frame_request? ? false : "application" }

  def index
    @teacher_status = params[:status].presence_in(%w[active inactive all]) || "active"
    @teacher_rows = teacher_rows
  end

  def new
    @teacher = User.new
    @teacher.avatar_key = teacher_avatar_keys.sample
  end

  def create
    attrs = teacher_params
    attrs[:gender] = nil unless %w[male female].include?(attrs[:gender])
    @teacher = User.new(attrs.merge(role: :teacher))
    pool = avatar_keys_for_gender(@teacher.gender)
    @teacher.avatar_key = pool.sample unless pool.include?(@teacher.avatar_key)

    result = Teachers::SaveWithAssignments.call(
      teacher: @teacher,
      attributes: {},
      school: @school,
      classroom_ids: []
    )

    if result.success?
      redirect_to school_teachers_path(@school),
        notice: t("schools.teachers.create.success"),
        status: :see_other
    else
      flash.now[:alert] = t("schools.teachers.create.failure")
      render_teacher_form(:new)
    end
  end

  def edit
    load_edit_form
  end

  def update
    selected_classroom_ids

    result =
      unless classroom_assignments_invalid?
        Teachers::SaveWithAssignments.call(
          teacher: @teacher,
          attributes: {},
          school: @school,
          classroom_ids: selected_classroom_ids,
          assignment_scope: :school
        )
      end

    if classroom_assignments_invalid?
      load_edit_form
      render_teacher_form(:edit)
    elsif result.success?
      redirect_to school_teachers_path(@school),
        notice: t("schools.teachers.update.success"),
        status: :see_other
    else
      load_edit_form
      render_teacher_form(:edit)
    end
  end

  def deactivate
    authorize @teacher, :deactivate_teacher?
    update_teacher_status(false)
  end

  def reactivate
    authorize @teacher, :reactivate_teacher?
    update_teacher_status(true)
  end

  private

  def set_school
    @school = policy_scope(School).find(params[:school_id])
  end

  def authorize_school_teacher_management
    authorize @school, :manage_teachers?
  end

  def set_teacher
    membership = @school.school_memberships.includes(:user).find_by!(user_id: params[:id])
    @teacher = membership.user
    raise ActiveRecord::RecordNotFound unless @teacher.teacher?
  end

  def teacher_rows
    @school.school_memberships
      .includes(user: [{ avatar_attachment: :blob }, { classroom_memberships: :classroom }])
      .order(:role, :id)
      .select { |membership| membership.user.teacher? }
      .select { |membership| @teacher_status == "all" || membership.user.active? == (@teacher_status == "active") }
      .map do |membership|
        teacher = membership.user
        classrooms = school_teacher_classrooms(teacher)
        classroom_names = classrooms.map(&:name)
        grades = classrooms.filter_map(&:grade).uniq.sort

        {
          teacher: teacher,
          school_role_label: teacher_school_role_label(membership),
          classroom_names: classroom_names,
          classroom_count: classroom_names.size,
          grade_label: grades.any? ? t("classrooms.index.grades", grades: grades.join(", ")) : t("classrooms.index.grade_unspecified")
        }
      end
  end

  def school_teacher_classrooms(teacher)
    teacher.classroom_memberships
      .select(&:teacher?)
      .filter_map(&:classroom)
      .select { |classroom| classroom.school_id == @school.id }
  end

  def teacher_school_role_label(membership)
    t(membership.manager? ? "schools.teachers.index.manager" : "schools.teachers.index.member")
  end

  def teacher_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :gender, :avatar_key)
  end

  def update_teacher_status(active)
    if @teacher.update(active: active, remember_created_at: nil)
      redirect_to school_teachers_path(@school, status: params[:status]),
        notice: t(active ? "teacher_status.reactivated" : "teacher_status.deactivated"),
        status: :see_other
    else
      redirect_to school_teachers_path(@school), alert: t("teacher_status.failure"), status: :see_other
    end
  end

  def avatar_keys_for_gender(gender)
    return User::TEACHER_MALE_AVATAR_KEYS if gender == "male"
    return User::TEACHER_FEMALE_AVATAR_KEYS if gender == "female"

    teacher_avatar_keys
  end

  def teacher_avatar_keys
    User.avatar_keys_for_role("teacher")
  end

  def selected_classroom_ids
    return @selected_classroom_ids if defined?(@selected_classroom_ids)

    raw_ids = Array(params[:classroom_ids]).reject(&:blank?)
    valid_raw_ids = raw_ids.select { |value| value.to_s.match?(/\A[1-9]\d*\z/) }
    requested_ids = valid_raw_ids.map(&:to_i).uniq
    classrooms = @school.classrooms.where(id: requested_ids).to_a
    @selected_classroom_ids = classrooms.map(&:id)

    if valid_raw_ids.size != raw_ids.size || @selected_classroom_ids.sort != requested_ids.sort
      @classroom_assignments_invalid = true
      @teacher.errors.add(:base, t("schools.teachers.errors.classroom_not_found"))
    end

    @selected_classroom_ids
  end

  def classroom_assignments_invalid?
    @classroom_assignments_invalid == true
  end

  def load_edit_form
    @classrooms = @school.classrooms.order(:created_at).load
    @teacher_classroom_ids =
      if params.key?(:classroom_ids)
        selected_classroom_ids
      else
        @teacher.classroom_memberships.teacher
          .joins(:classroom)
          .where(classrooms: { school_id: @school.id })
          .pluck(:classroom_id)
      end
    @teacher_classroom_names = @classrooms.select { |classroom| @teacher_classroom_ids.include?(classroom.id) }.map(&:name)
    @teacher_classroom_count = @teacher_classroom_names.size
  end

  def render_teacher_form(template)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "modal",
          partial: "schools/teachers/#{template}_modal"
        ), status: :unprocessable_entity
      end
      format.html do
        render template, formats: :html, status: :unprocessable_entity
      end
    end
  end
end
