class Admin::TeachersController < Admin::BaseController
  before_action :set_teacher, only: %i[edit update]
  before_action :set_status_teacher, only: %i[deactivate reactivate]

  def index
    prepare_school_filter
    @teacher_rows = teacher_rows
  end

  def new
    @teacher = User.new(role: :teacher)
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

    school = selected_school
    classroom_ids = selected_classroom_ids(school)
    result =
      unless school_assignment_invalid?
        Teachers::SaveWithAssignments.call(
          teacher: @teacher,
          attributes: {},
          school: school,
          classroom_ids: classroom_ids
        )
      end

    if result&.success?
      redirect_to admin_teachers_path,
                  notice: t('admin.teachers.create.success'),
                  status: :see_other
    else
      flash.now[:alert] = t('admin.teachers.create.failure')
      load_school_assignment_form
      render :new, formats: :html, status: :unprocessable_content
    end
  end

  def edit
    authorize @teacher
    load_edit_form
  end

  def update
    authorize @teacher, @teacher.teacher? ? :update? : :index?

    unless @teacher.teacher?
      @teacher.errors.add(:base, t('admin.teachers.errors.teacher_required'))
      load_edit_form
      render :edit, formats: :html, status: :unprocessable_content
      return
    end

    unless school_selection_submitted? && classroom_selection_submitted?
      @teacher.errors.add(:base, t('admin.teachers.errors.assignment_selection_required'))
      load_edit_form
      render :edit, formats: :html, status: :unprocessable_content
      return
    end

    school = selected_school
    classroom_ids = selected_classroom_ids(school)
    result =
      unless school_assignment_invalid?
        Teachers::SaveWithAssignments.call(
          teacher: @teacher,
          attributes: {},
          school: school,
          classroom_ids: classroom_ids
        )
      end

    if result&.success?
      redirect_to edit_admin_teacher_path(@teacher),
                  notice: t('admin.teachers.update.success'),
                  status: :see_other
    else
      load_edit_form
      render :edit, formats: :html, status: :unprocessable_content
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

  def teacher_rows
    scope = policy_scope(User)
            .teacher
            .with_attached_avatar
            .includes(school_membership: :school, classroom_memberships: :classroom)
    scope = scope.where(active: @teacher_status == 'active') unless @teacher_status == 'all'

    if @selected_school
      scope = scope.joins(:school_membership)
                   .where(school_memberships: { school_id: @selected_school.id })
    end

    scope.order(:created_at)
         .map do |teacher|
           school = teacher.school_membership&.school
           classrooms = teacher.classroom_memberships
                               .select(&:teacher?)
                               .map(&:classroom)
                               .compact
                               .sort_by { |classroom| [classroom.grade || Float::INFINITY, classroom.name.to_s, classroom.id] }
           membership = teacher.school_membership

           {
             teacher: teacher,
             school_name: school&.name || t('admin.teachers.index.unassigned_school'),
             school_color_key: school&.color_key,
             school_role: membership&.role,
             school_role_label: teacher_school_role_label(teacher),
             classrooms: classrooms
           }
    end
  end

  def prepare_school_filter
    @teacher_status = params[:status].presence_in(%w[active inactive all]) || 'active'
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
    return t('admin.teachers.index.unassigned_role') unless membership

    t(membership.manager? ? 'admin.teachers.index.manager' : 'admin.teachers.index.member')
  end

  def set_teacher
    @teacher = User.find(params[:id])
  end

  def set_status_teacher
    @teacher = User.teacher.find(params[:id])
  end

  def update_teacher_status(active)
    if @teacher.update(active: active, remember_created_at: nil)
      redirect_to edit_admin_teacher_path(@teacher),
                  notice: t(active ? 'teacher_status.reactivated' : 'teacher_status.deactivated'),
                  status: :see_other
    else
      @teacher.errors.add(:base, t('teacher_status.failure')) if @teacher.errors.empty?
      load_edit_form
      render :edit, formats: :html, status: :unprocessable_content
    end
  end

  def teacher_params
    params.require(:user).permit(:name, :email, :password, :gender, :avatar_key)
  end

  def avatar_keys_for_gender(gender)
    return User::TEACHER_MALE_AVATAR_KEYS if gender == 'male'
    return User::TEACHER_FEMALE_AVATAR_KEYS if gender == 'female'

    teacher_avatar_keys
  end

  def teacher_avatar_keys
    User.avatar_keys_for_role('teacher')
  end

  def selected_school
    return @selected_school if defined?(@selected_school)
    return nil if teacher_assignment_params[:school_id].blank?

    @selected_school = School.find_by(id: teacher_assignment_params[:school_id])
    if @selected_school&.active? ||
        @selected_school&.id == @teacher.school_membership&.school_id
      return @selected_school
    end

    @school_selection_invalid = true
    @teacher.errors.add(:base, t('admin.teachers.errors.school_not_found'))
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
      @teacher.errors.add(:base, t('admin.teachers.errors.classroom_not_found'))
    elsif !school_selection_invalid? && school.nil? && requested_ids.any?
      @classroom_selection_invalid = true
      @teacher.errors.add(:base, t('admin.teachers.errors.school_required_for_classrooms'))
    elsif school && Classroom.where(id: requested_ids).where.not(school_id: school.id).exists?
      @classroom_selection_invalid = true
      @teacher.errors.add(:base, t('admin.teachers.errors.classroom_school_mismatch'))
    elsif school&.inactive?
      current_ids = @teacher.classroom_memberships.teacher.pluck(:classroom_id)
      if (requested_ids - current_ids).any?
        @classroom_selection_invalid = true
        @teacher.errors.add(:base, t("school_status.inactive_school"))
      end
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
    load_school_assignment_form
  end

  def load_school_assignment_form
    current_school_id = @teacher.school_membership&.school_id
    @schools = School.active.or(School.where(id: current_school_id)).order(:name, :id).load
    @classrooms_by_school = Classroom.where(school_id: @schools.map(&:id)).order(:grade, :name, :id).group_by(&:school_id)
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

end
