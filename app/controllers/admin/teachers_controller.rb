class Admin::TeachersController < Admin::BaseController
  before_action :set_teacher, only: [:edit, :update]

  # 뷰에서 쓸 프레젠테이션 행 데이터
  Row = Struct.new(:teacher, :homeroom_names, :classroom_count, keyword_init: true)

  def index
    teachers = policy_scope(User)
      .where(role: :teacher)
      .includes(classroom_memberships: :classroom)   # N+1 예방
      .order(:created_at)

    @rows = teachers.map do |t|
      homerooms =
        t.classroom_memberships
         .teacher
         .map { |m| m.classroom&.name }
         .compact

      Row.new(
        teacher:         t,
        homeroom_names:  homerooms,
        classroom_count: t.classrooms.size
      )
    end
  end

  def new
    @teacher = User.new
    authorize @teacher
  end

  def create
    @teacher = User.new(teacher_params.merge(role: :teacher))
    authorize @teacher

    if @teacher.save
      redirect_to admin_teachers_path, notice: "새 교사 계정이 생성되었습니다."
    else
      flash.now[:alert] = "교사 계정 생성에 실패했습니다."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @teacher
    @classrooms = policy_scope(Classroom).order(:created_at)
    @teacher_classroom_ids = @teacher.classroom_memberships.teacher.pluck(:classroom_id)
  end

  def update
    authorize @teacher

    # 개인 정보(name/email/password)는 Devise에서 각 교사가 직접 수정.
    # 여기서는 담임 교실 매핑만 관리한다.
    update_homeroom_memberships!
    redirect_to admin_teachers_path, notice: "담임 교실 설정을 저장했습니다."
  end

  private

  def set_teacher
    @teacher = User.find(params[:id])
  end

  def teacher_params
    params.require(:user).permit(:name, :email, :password)
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