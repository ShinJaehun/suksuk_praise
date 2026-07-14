class Schools::TeachersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_school
  before_action :authorize_school_teacher_management
  before_action :set_teacher, only: %i[edit update]

  layout -> { turbo_frame_request? ? false : "application" }

  def index
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

    if create_teacher_for_school
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

    if classroom_assignments_invalid?
      load_edit_form
      render_teacher_form(:edit)
    elsif update_school_classroom_assignments
      redirect_to school_teachers_path(@school),
        notice: t("schools.teachers.update.success"),
        status: :see_other
    else
      load_edit_form
      render_teacher_form(:edit)
    end
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

  def avatar_keys_for_gender(gender)
    return User::TEACHER_MALE_AVATAR_KEYS if gender == "male"
    return User::TEACHER_FEMALE_AVATAR_KEYS if gender == "female"

    teacher_avatar_keys
  end

  def teacher_avatar_keys
    User.avatar_keys_for_role("teacher")
  end

  def create_teacher_for_school
    User.transaction do
      @teacher.save!
      SchoolMembership.create!(user: @teacher, school: @school)
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    handle_teacher_creation_error(error)
  end

  def update_school_classroom_assignments
    ClassroomMembership.transaction do
      current_memberships = @teacher.classroom_memberships
        .teacher
        .joins(:classroom)
        .where(classrooms: { school_id: @school.id })
      current_ids = current_memberships.pluck(:classroom_id)
      ids = selected_classroom_ids

      (ids - current_ids).each do |classroom_id|
        ClassroomMembership.find_or_create_by!(
          user_id: @teacher.id,
          classroom_id: classroom_id,
          role: "teacher"
        )
      end

      current_memberships.where(classroom_id: current_ids - ids).destroy_all
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    @teacher.errors.add(:base, error.record.errors.full_messages.to_sentence) if error.respond_to?(:record)
    false
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
        @teacher.classroom_memberships.teacher.joins(:classroom).where(classrooms: { school_id: @school.id }).pluck(:classroom_id)
      end
    @teacher_classroom_names = @classrooms.select { |classroom| @teacher_classroom_ids.include?(classroom.id) }.map(&:name)
    @teacher_classroom_count = @teacher_classroom_names.size
  end

  def handle_teacher_creation_error(error)
    record = error.record

    if record.equal?(@teacher)
      false
    elsif record.is_a?(SchoolMembership)
      record.errors.full_messages.each { |message| @teacher.errors.add(:base, message) }
      false
    elsif record.is_a?(CouponTemplate)
      @teacher.errors.add(:base, t("schools.teachers.errors.default_coupons_failed"))
      false
    else
      raise error
    end
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
