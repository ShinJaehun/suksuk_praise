class ClassroomStudentsController < ApplicationController
  include UserShowDataLoader
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_manage!, only: [:new, :create, :bulk_new, :bulk_create]
  before_action :set_student, only: [:show, :edit, :update, :destroy, :reset_password]

  def new
    @user = User.new
    respond_to do |f|
      f.html { render partial: "classroom_students/form", locals: { classroom: @classroom, user: @user } }
      f.turbo_stream { render partial: "classroom_students/form",
        locals: { classroom: @classroom, user: @user } }
    end
  end

  def create
    used_indices = used_avatar_indices_in_classroom
    @user = User.new(
      user_params.merge(
        role: "student",
        points: 0,
        default_avatar_index: pick_avatar_index(used_indices)
      )
    )
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

    used_indices = used_avatar_indices_in_classroom

    ApplicationRecord.transaction do
      count.times do |i|
        name = format("%s%02d", prefix, i + 1)
        email = "#{name}@suksuk.or.kr"
        avatar_index = pick_avatar_index(used_indices)
        used_indices << avatar_index
        user = User.create!(
          name: name,
          email: email,
          password: "123456",
          role: "student",
          points: 0,
          default_avatar_index: avatar_index
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

  def show
    authorize @student, :show?

    @user = @student
    @can_destroy_student = Pundit.policy!(current_user, @student).destroy_student?
    @can_create_compliment = policy(@classroom).create_compliment?
    @can_draw_coupon = policy(@classroom).draw_coupon?

    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: true,
      recent_in_classroom: true
    )

    @new_message = UserMessage.new
    @message_section_dom_id = dom_id(@user, :message_section)

    render "classroom_students/show"
  end

  def edit
    authorize @student, :manage_student_account?
    @user = @student
  end

  def update
    authorize @student, :manage_student_account?
    @user = @student

    if @student.update(managed_student_params)
      redirect_to edit_classroom_student_path(@classroom, @student), notice: "학생 계정 정보를 수정했습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def reset_password
    authorize @student, :manage_student_password?
    @user = @student

    if @student.update(password_reset_params)
      redirect_to edit_classroom_student_path(@classroom, @student), notice: "학생 비밀번호를 재설정했습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @student, :destroy_student?

    @student.destroy!
    redirect_to classroom_path(@classroom), notice: "학생 계정을 삭제했습니다.", status: :see_other
  end

  private
  
  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :password)
  end

  def set_student
    @student = User.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @student.student?
    raise ActiveRecord::RecordNotFound unless @classroom.classroom_memberships.exists?(user_id: @student.id)
  end

  def managed_student_params
    params.require(:user).permit(:name, :email)
  end

  def password_reset_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def authorize_manage!
    authorize @classroom, :manage_members?
  end

  def used_avatar_indices_in_classroom
    @classroom.classroom_memberships
      .joins(:user)
      .where.not(users: { default_avatar_index: nil })
      .distinct
      .pluck("users.default_avatar_index")
  end

  def pick_avatar_index(used_indices)
    available = (1..32).to_a - used_indices
    available.sample || rand(1..32)
  end
end
