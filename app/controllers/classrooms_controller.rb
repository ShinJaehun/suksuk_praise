class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom, only: [:show, :edit, :update, :destroy,:refresh_compliment_king]
  # before_action :require_teacher_or_admin!, only: [:new, :create, :edit, :update, :destroy]
  # before_action :authorize_classroom_owner!, only: [:edit, :update, :destroy]

  def index
    # @classrooms = current_user.admin? ? Classroom.all : current_user.classrooms.distinct #???
    @classrooms = policy_scope(Classroom).order(created_at: :desc)
  end

  def show
    # unless @classroom.users.include?(current_user) || current_user.admin?
    #   redirect_to classrooms_path, alert: "접근 권한 없음!"
    #   return
    # end

    # @students = @classroom.students

    # 오늘 하루 가장 많은 칭찬을 받은 학생 찾기
    # today = Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    #puts "################### #{today} ##################"
    # compliments_today = Compliment.where(classroom: @classroom, given_at: today)
    #   .group(:receiver_id)
    #   .count

    # if compliments_today.any?
    #   max_count = compliments_today.values.max
    #   @compliment_kings = @students.select { |u| compliments_today[u.id] == max_count }
    #   @compliment_king_count = max_count
    # #puts "################### #{@compliment_kings} ##################"
    # #puts "################### #{@compliment_king_count} ##################"
    # else
    #   @compliment_kings = []
    #   @compliment_king_count = 0
    # end

    authorize @classroom
    @students = @classroom.students
        
    today = Time.zone.today.all_day
    counts = Compliment.where(classroom: @classroom, given_at: today).group(:receiver_id).count
    if counts.any?
      max = counts.values.max
      @compliment_kings = @students.select { |s| counts[s.id] == max }
      @compliment_king_count = max
    else
      @compliment_kings = []
      @compliment_king_count = 0
    end
  end

  def refresh_compliment_king
    # @students = @classroom.classroom_memberships
    #   .includes(:user)
    #   .where(role: "student")
    #   .map(&:user)   #???

    # # 오늘 하루 가장 많은 칭찬을 받은 학생 찾기
    # today = Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    # compliments_today = Compliment.where(classroom: @classroom, given_at: today)
    #   .group(:receiver_id)
    #   .count

    # if compliments_today.any?
    #   max_count = compliments_today.values.max
    #   @compliment_kings = @students.select { |u| compliments_today[u.id] == max_count }
    #   @compliment_king_count = max_count
    # else
    #   @compliment_kings = []
    #   @compliment_king_count = 0
    # end

    # respond_to do |format|
    #   format.turbo_stream
    # end

    authorize @classroom, :show?
    @students = @classroom.students
    today = Time.zone.today.all_day
    counts = Compliment.where(classroom: @classroom, given_at: today).group(:receiver_id).count
    if counts.any?
      max = counts.values.max
      @compliment_kings = @students.select { |s| counts[s.id] == max }
      @compliment_king_count = max
    else
      @compliment_kings = []
      @compliment_king_count = 0
    end

    respond_to { |f| f.turbo_stream }
  end

  def new
    authorize Classroom
    @classroom = Classroom.new
  end

  def create
    authorize Classroom
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
    authorize @classroom
  end

  def update
    authorize @classroom
    if @classroom.update(classroom_params)
      redirect_to @classroom, notice: "교실 이름이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @classroom
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

  # def require_teacher_or_admin!
  #   unless current_user.teacher? || current_user.admin?
  #     redirect_to classrooms_path, alert: "접근 권한 없음!"
  #   end
  # end

  # def authorize_classroom_owner!
  #   return if current_user.admin?
  #   unless @classroom.classroom_memberships.exists?(user: current_user, role: "teacher")
  #     redirect_to classrooms_path, alert: "해당 교실에 대한 수정 권한 없음!"
  #   end
  # end
end
