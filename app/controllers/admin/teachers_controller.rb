class Admin::TeachersController < Admin::BaseController
  before_action :set_teacher, only: %i[edit update]
  layout -> { turbo_frame_request? ? false : "application" }

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
      redirect_to classrooms_path,
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

    if update_teacher_assignments
      redirect_to classrooms_path,
        notice: t("admin.teachers.update.success"),
        status: :see_other
    else
      load_edit_form
      render_teacher_form(:edit)
    end
  end

  private

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
    copy_membership_errors(error.record)
    false
  end

  def update_teacher_assignments
    school = selected_school if school_selection_submitted?
    selected_classroom_ids if classroom_assignments_submitted?
    return false if school_selection_invalid? || classroom_assignments_invalid?

    User.transaction do
      sync_school_membership!(school) if school_selection_submitted?
      sync_homeroom_memberships! if classroom_assignments_submitted?
    end
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    copy_membership_errors(error.record) if error.respond_to?(:record)
    false
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

  def sync_homeroom_memberships!
    ids = selected_classroom_ids
    current_memberships = @teacher.classroom_memberships.teacher
    current_ids = current_memberships.pluck(:classroom_id)

    (ids - current_ids).each do |classroom_id|
      ClassroomMembership.find_or_create_by!(
        user_id: @teacher.id,
        classroom_id: classroom_id,
        role: "teacher"
      )
    end

    current_memberships.where(classroom_id: current_ids - ids).destroy_all
  end

  def selected_school
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

  def classroom_assignments_submitted?
    params.key?(:classroom_ids)
  end

  def selected_classroom_ids
    return @selected_classroom_ids if defined?(@selected_classroom_ids)

    raw_ids = Array(params[:classroom_ids]).reject(&:blank?)
    valid_raw_ids = raw_ids.select { |value| value.to_s.match?(/\A[1-9]\d*\z/) }
    requested_ids = valid_raw_ids.map(&:to_i).uniq
    @selected_classroom_ids = policy_scope(Classroom).where(id: requested_ids).pluck(:id)
    if valid_raw_ids.size != raw_ids.size || @selected_classroom_ids.sort != requested_ids.sort
      invalid_classroom_assignment(@selected_classroom_ids)
    end
    @selected_classroom_ids
  end

  def invalid_classroom_assignment(selected_ids)
    @classroom_assignments_invalid = true
    @teacher.errors.add(:base, t("admin.teachers.errors.classroom_not_found"))
    @selected_classroom_ids = selected_ids
  end

  def classroom_assignments_invalid?
    @classroom_assignments_invalid == true
  end

  def load_edit_form
    load_school_options
    load_selected_school
    @classrooms = policy_scope(Classroom).includes(:school).order(:created_at).load
    @teacher_classroom_ids =
      if classroom_assignments_submitted?
        selected_classroom_ids
      else
        @teacher.classroom_memberships.teacher.pluck(:classroom_id)
      end
    selected_classrooms = @classrooms.select { |classroom| @teacher_classroom_ids.include?(classroom.id) }
    @teacher_classroom_names = selected_classrooms.map(&:name)
    @teacher_classroom_count = selected_classrooms.size
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
