class ClassroomStudentsController < ApplicationController
  include UserShowDataLoader
  include ActionView::RecordIdentifier

  MAX_BULK_STUDENTS = 30

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
    used_avatar_keys = used_avatar_keys_in_classroom
    attrs = user_params.merge(
      role: "student",
      points: 0
    )
    attrs[:avatar_key] = pick_avatar_key(attrs[:gender], used_avatar_keys)
    @user = User.new(attrs)
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
    genders = bulk_student_genders
    created = []
    prefix = Array('A'..'Z').sample(4).join
    student_pin = params[:student_pin].to_s.strip

    used_avatar_keys = used_avatar_keys_in_classroom

    ApplicationRecord.transaction do
      genders.each_with_index do |gender, i|
        name = format("%s%02d", prefix, i + 1)
        email = "#{name}@suksuk.or.kr"
        avatar_key = pick_avatar_key(gender, used_avatar_keys)
        used_avatar_keys << avatar_key if avatar_key.present?
        attrs = {
          name: name,
          email: email,
          password: "123456",
          role: "student",
          points: 0,
          gender: gender,
          avatar_key: avatar_key
        }
        attrs[:student_pin] = student_pin if student_pin.present?
        user = User.create!(attrs)
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
    message = t("students.bulk_create.failure", detail: e.record.errors.full_messages.to_sentence)
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), alert: message, status: :see_other }
      f.turbo_stream do
        flash.now[:alert] = message
        render :bulk_create_error, layout: "application"
      end
    end
  end

  def show
    authorize @student, :show?

    @user = @student
    @can_destroy_student = Pundit.policy!(current_user, @student).destroy_student?
    @can_create_compliment = policy(@classroom).create_compliment?
    @can_draw_coupon = policy(@classroom).draw_coupon?
    @student_messages_enabled = @classroom.student_messages_enabled?
    read_count = @student_messages_enabled ? mark_managed_student_messages_read : 0

    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: true,
      recent_in_classroom: true
    )

    @new_message = UserMessage.new
    @reply_message = UserMessage.new
    @message_teacher_options = student_message_teacher_options
    @message_section_dom_id = dom_id(@user, :message_section)
    broadcast_student_card_alerts_for(@classroom, @student) if read_count.positive?

    render "classroom_students/show"
  end

  def edit
    authorize @student, :manage_student_account?
    @user = @student
    @student_avatar_keys = student_avatar_keys
  end

  def update
    authorize @student, :manage_student_account?
    @user = @student
    attrs = managed_student_params
    if reassign_avatar_key?(attrs)
      attrs[:avatar_key] = pick_avatar_key(attrs[:gender], used_avatar_keys_in_classroom(excluding: @student))
    end

    if @student.update(attrs)
      redirect_to edit_classroom_student_path(@classroom, @student), notice: "학생 계정 정보를 수정했습니다."
    else
      @student_avatar_keys = student_avatar_keys
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
    params.require(:user).permit(:name, :email, :password, :student_pin, :gender)
  end

  def set_student
    @student = User.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @student.student?
    raise ActiveRecord::RecordNotFound unless @classroom.classroom_memberships.exists?(user_id: @student.id)
  end

  def managed_student_params
    params.require(:user).permit(:name, :email, :student_pin, :gender, :avatar_key).tap do |permitted|
      permitted.delete(:student_pin) if permitted[:student_pin].blank?
    end
  end

  def password_reset_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def authorize_manage!
    authorize @classroom, :manage_members?
  end

  def used_avatar_keys_in_classroom(excluding: nil)
    scope = @classroom.classroom_memberships
      .joins(:user)
      .where.not(users: { avatar_key: nil })
    scope = scope.where.not(users: { id: excluding.id }) if excluding
    scope.distinct.pluck("users.avatar_key")
  end

  def pick_avatar_key(gender, used_avatar_keys)
    pool = User.avatar_keys_for(gender)
    return nil if pool.empty?

    available = pool - used_avatar_keys
    available.sample || pool.sample
  end

  def student_avatar_keys
    User.avatar_keys_for_role("student")
  end

  def bulk_student_genders
    boy_count = [params[:boy_count].to_i, 0].max
    girl_count = [params[:girl_count].to_i, 0].max
    total_count = boy_count + girl_count

    unless params.key?(:boy_count) || params.key?(:girl_count)
      count = params[:count].to_i
      count = MAX_BULK_STUDENTS if count <= 0 || count > MAX_BULK_STUDENTS
      return Array.new(count, "boy")
    end

    if total_count < 1 || total_count > MAX_BULK_STUDENTS
      raise ActiveRecord::RecordInvalid.new(User.new.tap { |user| user.errors.add(:base, "한 번에 자동 생성할 수 있는 학생은 최대 #{MAX_BULK_STUDENTS}명입니다.") })
    end

    Array.new(boy_count, "boy") + Array.new(girl_count, "girl")
  end

  def reassign_avatar_key?(attrs)
    return false if attrs[:avatar_key].present?

    attrs[:gender].present? &&
      attrs[:gender] != @student.gender &&
      !@student.avatar.attached?
  end

  def student_message_teacher_options
    return User.none unless current_user == @student && @classroom.student_can_start_messages?

    User.teacher
      .joins(:classroom_memberships)
      .where(classroom_memberships: { classroom_id: @classroom.id, role: "teacher" })
      .distinct
      .order(:name, :id)
  end

  def mark_managed_student_messages_read
    return 0 unless current_user.admin? || current_user.teacher?

    mark_unread_student_messages_read_for(@classroom, @student)
  end
end
