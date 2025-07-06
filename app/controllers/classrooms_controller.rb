class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom, only: [:show, :edit, :update, :destroy]
  before_action :require_teacher_or_admin!, only: [:new, :create, :edit, :update, :destroy]
  before_action :authorize_classroom_owner!, only: [:edit, :update, :destroy]

  def index
    @classrooms = current_user.admin? ? Classroom.all : current_user.classrooms.distinct #???
  end

  def show
    unless @classroom.users.include?(current_user) || current_user.admin?
      redirect_to classrooms_path, alert: "접근 권한 없음!"
      return
    end

    @students = @classroom.classroom_memberships
      .includes(:user)
      .where(role: "student")
      .map(&:user)   #???
  end

  def new
    @classroom = Classroom.new
  end

  def create
    @classroom = Classroom.new(classroom_params)
    if @classroom.save
      ClassroomMembership.create!(
        classroom: @classroom,
        user: current_user,
        role: "teacher"
      )
      redirect_to classroom_path(@classroom), notice: "교실이 생성되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @classroom.update(classroom_params)
      redirect_to @classroom, notice: "교실 이름이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @classroom.destroy
    redirect_to classrooms_path, notice: "교실이 삭제되었습니다."
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def classroom_params
    params.require(:classroom).permit(:name)
  end

  def require_teacher_or_admin!
    unless current_user.teacher? || current_user.admin?
      redirect_to classrooms_path, alert: "접근 권한 없음!"
    end
  end

  def authorize_classroom_owner!
    return if current_user.admin?
    unless @classroom.classroom_memberships.exists?(user: current_user, role: "teacher")
      redirect_to classrooms_path, alert: "해당 교실에 대한 수정 권한 없음!"
    end
  end
end
