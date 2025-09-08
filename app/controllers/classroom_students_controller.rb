class ClassroomStudentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom
  # before_action :require_teacher_or_admin!
  before_action :authorize_manage!

  def new
    @user = User.new
    respond_to do |f|
      f.turbo_stream { render partial: "classroom_students/form", locals: { classroom: @classroom, user: @user } }
      f.html { render partial: "classroom_students/form", locals: { classroom: @classroom, user: @user } }
    end
  end

  def create
    @user = User.new(user_params.merge(role: "student", points: 0, avatar: random_avatar))
    if @user.save
      @classroom.classroom_memberships.create!(user: @user, role: "student")
      respond_to do |f|
        f.turbo_stream
        f.html { redirect_to @classroom, notice: "학생이 추가되었습니다." }
      end
    else
      respond_to do |f|
        f.turbo_stream { render :new, status: :unprocessable_entity }
        f.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def bulk_new
    respond_to do |f|
      f.turbo_stream { render partial: "classroom_students/bulk_form", locals: { classroom: @classroom } }
      f.html { render partial: "classroom_students/bulk_form", locals: { classroom: @classroom } }
    end
  end

  def bulk_create
    count = params[:count].to_i
    count = 30 if count <= 0 || count > 30
    created = []
    prefix = Array('A'..'Z').sample(4).join

    ApplicationRecord.transaction do
      count.times do |i|
        name = format("%s%02d", prefix, i + 1)
        email = "#{name}@suksuk.or.kr"
        user = User.create!(
          name: name,
          email: email,
          password: "123456",
          role: "student",
          points: 0,
          avatar: random_avatar
        )
        @classroom.classroom_memberships.create!(user: user, role: "student")
        created << user
      end
    end

    @students = @classroom.students.reload

    respond_to do |f|
      f.turbo_stream
      f.html { redirect_to @classroom, notice: "#{created.size}명의 학생이 자동 생성되었습니다." }
    end

  rescue ActiveRecord::RecordInvalid => e
    redirect_to @classroom, alert: "생성 실패: #{e.record.errors.full_messages.to_sentence}"
  end

  private
  
  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :password)
  end

  # def require_teacher_or_admin!
  #   redirect_to @classroom, alert: "권한 없음" unless current_user.admin? || current_user.teacher?
  # end

  def random_avatar
    "avatars/avatar_#{rand(1..30)}.png"
  end

  def authorize_manage!
    authorize @classroom, :update?
  end
end