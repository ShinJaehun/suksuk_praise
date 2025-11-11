class Admin::TeachersController < Admin::BaseController
  def index
    @teachers = policy_scope(User).where(role: :teacher).order(:created_at)
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

  private

  def teacher_params
    params.require(:user).permit(:name, :email, :password)
  end
end