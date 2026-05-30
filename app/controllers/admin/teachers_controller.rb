class Admin::TeachersController < Admin::BaseController
  before_action :set_teacher, only: [:edit, :update]

  def new
    @teacher = User.new
    @teacher.avatar_key = teacher_avatar_keys.sample
    authorize @teacher
  end

  def create
    attrs = teacher_params
    attrs[:gender] = nil unless %w[male female].include?(attrs[:gender])
    @teacher = User.new(attrs.merge(role: :teacher))
    pool = avatar_keys_for_gender(@teacher.gender)
    @teacher.avatar_key = pool.sample unless pool.include?(@teacher.avatar_key)
    authorize @teacher

    if @teacher.save
      redirect_to classrooms_path, notice: t("admin.teachers.create.success")
    else
      flash.now[:alert] = t("admin.teachers.create.failure")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @teacher
    @classrooms = policy_scope(Classroom).order(:created_at)
    @teacher_classroom_ids = @teacher.classroom_memberships.teacher.pluck(:classroom_id)
    @teacher_classroom_names = @classrooms
      .select { |classroom| @teacher_classroom_ids.include?(classroom.id) }
      .map(&:name)
    @teacher_classroom_count = @teacher_classroom_names.size
  end

  def update
    authorize @teacher

    # 개인 정보(name/email/password)는 Devise에서 각 교사가 직접 수정.
    # 여기서는 담임 교실 매핑만 관리한다.
    update_homeroom_memberships!
    redirect_to classrooms_path, notice: t("admin.teachers.update.success")

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

  def update_homeroom_memberships!
    ids = Array(params[:classroom_ids]).reject(&:blank?).map(&:to_i)

    # 기존 teacher memberships
    current_ids = @teacher.classroom_memberships.teacher.pluck(:classroom_id)

    # 추가해야 할 classrooms
    (ids - current_ids).each do |classroom_id|
      ClassroomMembership.find_or_create_by!(
        user_id: @teacher.id,
        classroom_id: classroom_id,
        role: 'teacher'
      )
    end

    # 제거해야 할 classrooms
    (current_ids - ids).each do |classroom_id|
      membership = ClassroomMembership.find_by(
        user_id: @teacher.id,
        classroom_id: classroom_id,
        role: 'teacher'
      )
      membership&.destroy!
    end
  end
end
