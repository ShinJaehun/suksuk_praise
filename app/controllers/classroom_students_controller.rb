class ClassroomStudentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_manage!

  def new
    @user = User.new
    respond_to do |f|
      f.html { render partial: "classroom_students/form", locals: { classroom: @classroom, user: @user } }
      f.turbo_stream { render partial: "classroom_students/form",
        locals: { classroom: @classroom, user: @user } }
    end
  end

  def create
    @user = User.new(user_params.merge(role: "student", points: 0, avatar: random_avatar))
    if @user.save
      @classroom.classroom_memberships.create!(user: @user, role: "student")

      respond_to do |f|
        f.html { redirect_to @classroom, notice: t("students.create.success"), status: :see_other }
        f.turbo_stream do
          flash.now[:notice] = t("students.create.success")          
          render :create, layout: "application"
        end
      end
    else
      message = @user.errors.full_messages.to_sentence.presence ||
        t("students.create.failure_fallback")

      respond_to do |f|
        f.html { redirect_to @classroom, alert: message, status: :see_other }
        f.turbo_stream do
          flash.now[:alert] = message          
          render "classroom_students/create_error", layout: "application",
            status: :unprocessable_entity
        end
      end
    end
  end

  def bulk_new
    respond_to do |f|
      f.html { render partial: "classroom_students/bulk_form", locals: { classroom: @classroom } }
      f.turbo_stream { render partial: "classroom_students/bulk_form", locals: { classroom: @classroom } }
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

    message = t("students.bulk_create.success", count: created.size)
    respond_to do |f|
      f.html { redirect_to @classroom, notice: message, status: :see_other }
      f.turbo_stream do
        flash.now[:notice] = message
        render :bulk_create, layout: "application" 
      end
    end

  rescue ActiveRecord::RecordInvalid => e
    redirect_to @classroom,
      alert: t("students.bulk_create.failure", detail: e.record.errors.full_messages.to_sentence),
      status: :see_other
  end

  private
  
  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :password)
  end

  def random_avatar
    "avatars/avatar_#{rand(1..30)}.png"
  end

  def authorize_manage!
    authorize @classroom, :manage_members?
  end
end