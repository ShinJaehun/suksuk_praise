class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  # before_action :set_classroom, only: [:show, :edit, :update, :destroy,
  #   :refresh_compliment_king, :new_student, :add_student, :bulk_students, :create_bulk_students]
  before_action :set_classroom, only: [:show, :edit, :update, :destroy,:refresh_compliment_king]
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

    #@students = @classroom.classroom_memberships
      #.includes(:user)
      #.where(role: "student")
      #.map(&:user)   #???

    @students = @classroom.students

    # 오늘 하루 가장 많은 칭찬을 받은 학생 찾기
    today = Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    #puts "################### #{today} ##################"
    compliments_today = Compliment.where(classroom: @classroom, given_at: today)
      .group(:receiver_id)
      .count

    if compliments_today.any?
      max_count = compliments_today.values.max
      @compliment_kings = @students.select { |u| compliments_today[u.id] == max_count }
      @compliment_king_count = max_count
    #puts "################### #{@compliment_kings} ##################"
    #puts "################### #{@compliment_king_count} ##################"
    else
      @compliment_kings = []
      @compliment_king_count = 0
    end
  end

  def refresh_compliment_king
    @students = @classroom.classroom_memberships
      .includes(:user)
      .where(role: "student")
      .map(&:user)   #???

    # 오늘 하루 가장 많은 칭찬을 받은 학생 찾기
    today = Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    compliments_today = Compliment.where(classroom: @classroom, given_at: today)
      .group(:receiver_id)
      .count

    if compliments_today.any?
      max_count = compliments_today.values.max
      @compliment_kings = @students.select { |u| compliments_today[u.id] == max_count }
      @compliment_king_count = max_count
    else
      @compliment_kings = []
      @compliment_king_count = 0
    end

    respond_to do |format|
      format.turbo_stream
    end
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

  # def new_student
  #   @user = User.new

  #   respond_to do |format|
  #     format.html { render partial: "classrooms/modal_student_form", locals: { classroom: @classroom, user: @user } }
  #   end
  # end

  # def add_student
  #   @user = User.new(user_params.merge(role: "student", points: 0, avatar: random_avatar))
  #   if @user.save
  #     ClassroomMembership.create!(user: @user, classroom: @classroom, role: "student")
  #     respond_to do |format|
  #       format.turbo_stream
  #       format.html { redirect_to classroom_path(@classroom), notice: "학생이 추가되었습니다." }
  #     end
  #   else
  #     respond_to do |format|
  #       format.html { render partial: "classrooms/modal_student_form", locals: { classroom: @classroom, user: @user }, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # def bulk_students
  #   respond_to do |format|
  #     format.html { render partial: "classrooms/modal_bulk_students_form", locals: { classroom: @classroom } }
  #   end
  # end

  # def create_bulk_students
  #   count = params[:count].to_i
  #   count = 30 if count <= 0 || count >= 30 # 기본값 및 최대값 제한

  #   created_users = []

  #   rand_chars = Array('A'..'Z').sample(4).join

  #   count.times do |i|
  #     num_str = format('%02d', i+1)
  #     name = "#{rand_chars}#{num_str}"
  #     email = "#{name}@suksuk"
  #     user = User.new(
  #       name: name,
  #       email: email,
  #       password: "123456", # 기본 비밀번호(원하면 랜덤 생성도 가능)
  #       role: "student",
  #       points: 0,
  #       avatar: random_avatar
  #     )
  #     if user.save
  #       ClassroomMembership.create!(user: user, classroom: @classroom, role: "student")
  #       created_users << user
  #     end
  #   end

  #   respond_to do |format|
  #     format.turbo_stream
  #     format.html { redirect_to classroom_path(@classroom), notice: "#{created_users.size}명의 학생이 자동 생성되었습니다." }
  #   end
  # end

  def destroy
    @classroom.destroy
    redirect_to classrooms_path, notice: "교실이 삭제되었습니다."
  end

  private

  # def user_params
  #   params.require(:user).permit(:name, :email, :password)
  # end

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

  # def random_avatar
  #   "avatars/avatar_#{rand(1..30)}.png"
  # end
end
