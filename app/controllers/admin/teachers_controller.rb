class Admin::TeachersController < Admin::BaseController
  before_action :set_teacher, only: %i[edit update]
  layout -> { turbo_frame_request? ? false : "application" }

  def index
    prepare_school_filter
    @teacher_rows = teacher_rows
  end

  def new
    @teacher = User.new
    @teacher.avatar_key = teacher_avatar_keys.sample
    authorize @teacher
    load_school_options
    load_selected_school
  end

  def create
    attrs = teacher_params
    attrs[:gender] = nil unless %w[male female].include?(attrs[:gender])
    @teacher = User.new(attrs.merge(role: :teacher))
    pool = avatar_keys_for_gender(@teacher.gender)
    @teacher.avatar_key = pool.sample unless pool.include?(@teacher.avatar_key)
    authorize @teacher

    if create_teacher_with_school_membership
      redirect_to admin_teachers_path,
        notice: t("admin.teachers.create.success"),
        status: :see_other
    else
      flash.now[:alert] = t("admin.teachers.create.failure")
      load_school_options
      load_selected_school
      render_teacher_form(:new)
    end
  end

  def edit
    authorize @teacher
    load_edit_form
  end

  def update
    authorize @teacher

    if update_teacher_school_membership
      redirect_to admin_teachers_path,
        notice: t("admin.teachers.update.success"),
        status: :see_other
    else
      load_edit_form
      render_teacher_form(:edit)
    end
  end

  private

  def teacher_rows
    scope = policy_scope(User)
      .teacher
      .with_attached_avatar
      .includes(school_membership: :school, classroom_memberships: :classroom)

    if @selected_school
      scope = scope.joins(:school_membership)
        .where(school_memberships: { school_id: @selected_school.id })
    end

    scope.order(:created_at)
      .map do |teacher|
        classrooms = teacher.classroom_memberships
          .select(&:teacher?)
          .map(&:classroom)
          .compact
        classroom_names = classrooms.map(&:name)
        grades = classrooms.filter_map(&:grade).uniq.sort

        {
          teacher: teacher,
          school_name: teacher.school_membership&.school&.name || t("admin.teachers.index.unassigned_school"),
          school_role_label: teacher_school_role_label(teacher),
          grade_label: grades.any? ? t("classrooms.index.grades", grades: grades.join(", ")) : t("classrooms.index.grade_unspecified"),
          classroom_names: classroom_names,
          classroom_count: classroom_names.size
        }
      end
  end

  def prepare_school_filter
    @filter_schools = policy_scope(School).order(:name, :id).load
    @selected_school = @filter_schools.detect { |school| school.id == school_filter_id }
  end

  def school_filter_id
    value = params[:school_id].to_s
    return nil unless value.match?(/\A[1-9]\d*\z/)

    value.to_i
  end

  def teacher_school_role_label(teacher)
    membership = teacher.school_membership
    return t("admin.teachers.index.unassigned_role") unless membership

    t(membership.manager? ? "admin.teachers.index.manager" : "admin.teachers.index.member")
  end

  def set_teacher
    @teacher = User.find(params[:id])
  end

  def teacher_params
    params.require(:user).permit(:name, :email, :password, :gender, :avatar_key)
  end

  def avatar_keys_for_gender(gender)
    return User::TEACHER_MALE_AVATAR_KEYS if gender == "male"
    return User::TEACHER_FEMALE_AVATAR_KEYS if gender == "female"

    teacher_avatar_keys
  end

  def teacher_avatar_keys
    User.avatar_keys_for_role("teacher")
  end

  def create_teacher_with_school_membership
    school = selected_school
    return false if school_selection_invalid?

    User.transaction do
      @teacher.save!
      SchoolMembership.create!(user: @teacher, school: school) if school
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    handle_teacher_creation_error(error)
  end

  def update_teacher_school_membership
    school = selected_school if school_selection_submitted?
    return false if school_selection_invalid?
    return false if school_selection_submitted? && teacher_school_assignment_conflict?(school)

    User.transaction do
      sync_school_membership!(school) if school_selection_submitted?
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    copy_membership_errors(error.record) if error.respond_to?(:record)
    false
  end

  def teacher_school_assignment_conflict?(target_school)
    teacher_classrooms = @teacher.classroom_memberships.teacher.joins(:classroom)
    conflict =
      if target_school
        teacher_classrooms.where.not(classrooms: { school_id: target_school.id }).exists?
      else
        teacher_classrooms.exists?
      end

    if conflict
      @teacher.errors.add(
        :base,
        t("admin.teachers.errors.classroom_assignments_must_be_cleared")
      )
    end
    conflict
  end

  def sync_school_membership!(school)
    membership = @teacher.school_membership

    if school.nil?
      membership&.destroy!
    elsif membership
      membership.update!(school: school)
    else
      SchoolMembership.create!(user: @teacher, school: school)
    end
  end

  def selected_school
    return @selected_school if defined?(@selected_school)
    return nil if params[:school_id].blank?

    @selected_school = School.find_by(id: params[:school_id])
    return @selected_school if @selected_school

    @school_selection_invalid = true
    @teacher.errors.add(:base, t("admin.teachers.errors.school_not_found"))
    nil
  end

  def school_selection_invalid?
    @school_selection_invalid == true
  end

  def school_selection_submitted?
    params.key?(:school_id)
  end

  def load_edit_form
    load_school_options
    load_selected_school
    classrooms = @teacher.classroom_memberships.teacher.includes(:classroom).map(&:classroom).compact
    @teacher_classroom_names = classrooms.map(&:name)
    @teacher_classroom_count = classrooms.size
  end

  def load_school_options
    @schools = School.order(:name, :id)
  end

  def load_selected_school
    @selected_school_id =
      if school_selection_submitted?
        params[:school_id].presence&.to_i
      else
        @teacher.school_membership&.school_id
      end
  end

  def copy_membership_errors(record)
    return unless record.is_a?(SchoolMembership)

    record.errors.full_messages.each { |message| @teacher.errors.add(:base, message) }
  end

  def handle_teacher_creation_error(error)
    record = error.record

    if record.equal?(@teacher)
      false
    elsif record.is_a?(SchoolMembership)
      copy_membership_errors(record)
      false
    elsif record.is_a?(CouponTemplate)
      @teacher.errors.add(:base, t("admin.teachers.errors.default_coupons_failed"))
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
          partial: "admin/teachers/#{template}_modal"
        ), status: :unprocessable_entity
      end
      format.html do
        render template, formats: :html, status: :unprocessable_entity
      end
    end
  end
end
