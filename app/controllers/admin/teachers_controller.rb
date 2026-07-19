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
    load_school_assignment_form
  end

  def create
    attrs = teacher_params
    attrs[:gender] = nil unless %w[male female].include?(attrs[:gender])
    @teacher = User.new(attrs.merge(role: :teacher))
    pool = avatar_keys_for_gender(@teacher.gender)
    @teacher.avatar_key = pool.sample unless pool.include?(@teacher.avatar_key)
    authorize @teacher

    if create_teacher_with_assignments
      redirect_to admin_teachers_path,
        notice: t("admin.teachers.create.success"),
        status: :see_other
    else
      flash.now[:alert] = t("admin.teachers.create.failure")
      load_school_assignment_form
      render_teacher_form(:new)
    end
  end

  def edit
    authorize @teacher
    load_edit_form
  end

  def update
    authorize @teacher, @teacher.teacher? ? :update? : :index?

    unless @teacher.teacher?
      @teacher.errors.add(:base, t("admin.teachers.errors.teacher_required"))
      load_edit_form
      render_teacher_form(:edit)
      return
    end

    if update_teacher_assignments
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

  def create_teacher_with_assignments
    school = selected_school
    classroom_ids = selected_classroom_ids(school)
    return false if school_assignment_invalid?

    User.transaction do
      @teacher.save!
      SchoolMembership.create!(user: @teacher, school: school) if school
      classroom_ids.each do |classroom_id|
        ClassroomMembership.create!(user: @teacher, classroom_id: classroom_id, role: :teacher)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    handle_teacher_creation_error(error)
  end

  def update_teacher_assignments
    unless school_selection_submitted? && classroom_selection_submitted?
      @teacher.errors.add(:base, t("admin.teachers.errors.assignment_selection_required"))
      return false
    end

    school = selected_school
    classroom_ids = selected_classroom_ids(school)
    return false if school_assignment_invalid?

    User.transaction do
      sync_teacher_classroom_assignments!(classroom_ids, before: true)
      sync_school_membership!(school)
      sync_teacher_classroom_assignments!(classroom_ids, before: false)
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    if error.respond_to?(:record)
      copy_assignment_errors(error.record)
    else
      @teacher.errors.add(:base, t("admin.teachers.errors.assignment_save_failed"))
    end
    false
  end

  def sync_school_membership!(school)
    membership = @teacher.school_membership

    if school.nil?
      membership&.destroy!
    elsif membership
      attributes = { school: school }
      attributes[:role] = :member if membership.school_id != school.id
      membership.update!(attributes)
    else
      SchoolMembership.create!(user: @teacher, school: school)
    end
  end

  def sync_teacher_classroom_assignments!(classroom_ids, before:)
    current_memberships = @teacher.classroom_memberships.teacher
    current_ids = current_memberships.pluck(:classroom_id)

    if before
      current_memberships.where(classroom_id: current_ids - classroom_ids).find_each(&:destroy!)
    else
      (classroom_ids - current_ids).each do |classroom_id|
        ClassroomMembership.create!(user: @teacher, classroom_id: classroom_id, role: :teacher)
      end
    end
  end

  def selected_school
    return @selected_school if defined?(@selected_school)
    return nil if teacher_assignment_params[:school_id].blank?

    @selected_school = School.find_by(id: teacher_assignment_params[:school_id])
    return @selected_school if @selected_school

    @school_selection_invalid = true
    @teacher.errors.add(:base, t("admin.teachers.errors.school_not_found"))
    nil
  end

  def school_selection_invalid?
    @school_selection_invalid == true
  end

  def selected_classroom_ids(school)
    return @selected_classroom_ids if defined?(@selected_classroom_ids)

    raw_ids = Array(teacher_assignment_params[:classroom_ids]).reject(&:blank?)
    valid_raw_ids = raw_ids.select { |value| value.to_s.match?(/\A[1-9]\d*\z/) }
    requested_ids = valid_raw_ids.map(&:to_i).uniq
    @selected_classroom_ids = requested_ids

    if valid_raw_ids.size != raw_ids.size || Classroom.where(id: requested_ids).count != requested_ids.size
      @classroom_selection_invalid = true
      @teacher.errors.add(:base, t("admin.teachers.errors.classroom_not_found"))
    elsif !school_selection_invalid? && school.nil? && requested_ids.any?
      @classroom_selection_invalid = true
      @teacher.errors.add(:base, t("admin.teachers.errors.school_required_for_classrooms"))
    elsif school && Classroom.where(id: requested_ids).where.not(school_id: school.id).exists?
      @classroom_selection_invalid = true
      @teacher.errors.add(:base, t("admin.teachers.errors.classroom_school_mismatch"))
    end

    @selected_classroom_ids
  end

  def school_assignment_invalid?
    school_selection_invalid? || @classroom_selection_invalid == true
  end

  def school_selection_submitted?
    teacher_assignment_params.key?(:school_id)
  end

  def classroom_selection_submitted?
    teacher_assignment_params.key?(:classroom_ids)
  end

  def load_edit_form
    classrooms = @teacher.classroom_memberships.teacher.includes(:classroom).map(&:classroom).compact
    @teacher_classroom_names = classrooms.map(&:name)
    @teacher_classroom_count = classrooms.size
    load_school_assignment_form
  end

  def load_school_assignment_form
    @schools = School.order(:name, :id).load
    @classrooms_by_school = Classroom.where(school_id: @schools.map(&:id)).order(:name, :id).group_by(&:school_id)
    load_selected_school
    @selected_classroom_ids =
      if teacher_assignment_params.key?(:classroom_ids)
        Array(teacher_assignment_params[:classroom_ids]).filter_map do |value|
          value.to_i if value.to_s.match?(/\A[1-9]\d*\z/)
        end.uniq
      elsif @teacher.persisted?
        @teacher.classroom_memberships.teacher.pluck(:classroom_id)
      else
        []
      end
  end

  def load_selected_school
    @selected_school_id =
      if school_selection_submitted?
        teacher_assignment_params[:school_id].presence&.to_i
      else
        @teacher.school_membership&.school_id
      end
  end

  def teacher_assignment_params
    @teacher_assignment_params ||= params.permit(:school_id, classroom_ids: [])
  end

  def copy_assignment_errors(record)
    return unless record.is_a?(SchoolMembership) || record.is_a?(ClassroomMembership)

    record.errors.full_messages.each { |message| @teacher.errors.add(:base, message) }
  end

  def handle_teacher_creation_error(error)
    unless error.respond_to?(:record)
      @teacher.errors.add(:base, t("admin.teachers.errors.assignment_save_failed"))
      return false
    end

    record = error.record

    if record.equal?(@teacher)
      false
    elsif record.is_a?(SchoolMembership) || record.is_a?(ClassroomMembership)
      copy_assignment_errors(record)
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
