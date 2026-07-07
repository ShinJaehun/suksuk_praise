class ClassroomStudentsController < ApplicationController
  include UserShowDataLoader
  include StudentWeeklyDashboardLoader
  include ActionView::RecordIdentifier

  MAX_BULK_STUDENTS = 30
  helper_method :return_to_context

  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_manage!, only: [:new, :create, :bulk_new, :bulk_create]
  before_action :set_student, only: [:show, :dashboard, :activity, :coupon_assignment, :edit, :update, :destroy, :deactivate, :reactivate, :reset_password]
  before_action :ensure_active_self_student!, only: [:show, :dashboard, :activity]

  def new
    @user = User.new
    respond_to do |f|
      f.html { render partial: "classroom_students/form", locals: { classroom: @classroom, user: @user, return_to: return_to_context } }
      f.turbo_stream { render partial: "classroom_students/form",
        locals: { classroom: @classroom, user: @user, return_to: return_to_context } }
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
        f.html { redirect_to create_success_path, notice: t("students.create.success"), status: :see_other }
        f.turbo_stream do
          flash.now[:notice] = t("students.create.success")
          if members_return_to?
            load_members_student_management!
            render :create_for_members, layout: "application"
          else
            render :create, layout: "application"
          end
        end
      end
    else
      message = @user.errors.full_messages.to_sentence.presence ||
        t("students.create.failure_fallback")

      respond_to do |f|
        f.html { redirect_to create_success_path, alert: message, status: :see_other }
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
      f.html { render partial: "classroom_students/bulk_form", locals: { classroom: @classroom, return_to: return_to_context } }
      f.turbo_stream { render partial: "classroom_students/bulk_form", locals: { classroom: @classroom, return_to: return_to_context } }
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
      f.html { redirect_to create_success_path, notice: message, status: :see_other }
      f.turbo_stream do
        flash.now[:notice] = message
        if members_return_to?
          load_members_student_management!
          render :bulk_create_for_members, layout: "application"
        else
          render :bulk_create, layout: "application"
        end
      end
    end

  rescue ActiveRecord::RecordInvalid => e
    message = t("students.bulk_create.failure", detail: e.record.errors.full_messages.to_sentence)
    respond_to do |f|
      f.html { redirect_to create_success_path, alert: message, status: :see_other }
      f.turbo_stream do
        flash.now[:alert] = message
        render :bulk_create_error, layout: "application", status: :unprocessable_entity
      end
    end
  end

  def show
    authorize @student, :show?

    @user = @student
    load_student_profile_permissions!
    read_count = @student_messages_enabled ? mark_managed_student_messages_read : 0

    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: false,
      recent_in_classroom: true
    )
    @pending_coupon_use_request_count = @pending_coupon_use_requests_by_coupon_id.size
    @can_issue_coupon = @can_draw_coupon && @student_active_in_classroom

    broadcast_student_card_alerts_for(@classroom, @student) if read_count.positive?

    render "classroom_students/show"
  end

  def activity
    authorize @student, :show?

    @user = @student
    load_student_profile_permissions!
    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: true,
      recent_in_classroom: true
    )
  end

  def dashboard
    authorize @student, :show?

    @user = @student
    load_student_profile_permissions!
    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: false,
      recent_in_classroom: true
    )
    load_student_weekly_dashboard!(student: @student, classroom: @classroom)
  end

  def coupon_assignment
    authorize @student, :show?
    authorize @classroom, :draw_coupon?
    raise ActiveRecord::RecordNotFound unless active_student_in_classroom?

    @user = @student
    @available_coupon_templates = policy_scope(CouponTemplate).active.ordered_by_title

    render partial: "classroom_students/coupon_assignment_card",
      locals: {
        classroom: @classroom,
        user: @user,
        available_coupon_templates: @available_coupon_templates
      }
  end

  def edit
    authorize @classroom, :manage_members?
    load_student_edit_form!
  end

  def update
    authorize @classroom, :manage_members?
    load_student_edit_form!
    attrs = managed_student_params
    if reassign_avatar_key?(attrs)
      attrs[:avatar_key] = pick_avatar_key(attrs[:gender], used_avatar_keys_in_classroom(excluding: @student))
    end

    if @student.update(attrs)
      redirect_to edit_classroom_student_path(@classroom, @student), notice: "학생 계정 정보를 수정했습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def reset_password
    authorize @classroom, :manage_members?
    load_student_edit_form!

    if @student.update(password_reset_params)
      redirect_to edit_classroom_student_path(@classroom, @student), notice: "학생 비밀번호를 재설정했습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @classroom, :manage_members?
    student_membership.inactive!

    redirect_to classroom_members_path(@classroom, status: "inactive"),
      notice: t("students.deactivate.success"),
      status: :see_other
  end

  def deactivate
    authorize @classroom, :manage_members?
    student_membership.inactive!

    redirect_to classroom_members_path(@classroom, status: "inactive"),
      notice: t("students.deactivate.success"),
      status: :see_other
  end

  def reactivate
    authorize @classroom, :manage_members?
    student_membership.active!

    redirect_to classroom_members_path(@classroom, status: "active"),
      notice: t("students.reactivate.success"),
      status: :see_other
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

  def student_membership
    @student_membership ||= @classroom.classroom_memberships.find_by!(
      user_id: @student.id,
      role: "student"
    )
  end

  def load_student_edit_form!
    @user = @student
    @student_membership = student_membership
    @student_avatar_keys = student_avatar_keys
  end

  def ensure_active_self_student!
    return unless current_user&.student? && current_user.id == @student.id
    return if active_student_in_classroom?

    raise ActiveRecord::RecordNotFound
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

  def return_to_context
    params[:return_to].presence_in(%w[members])
  end

  def members_return_to?
    return_to_context == "members"
  end

  def create_success_path
    return classroom_members_path(@classroom, status: "active") if members_return_to?

    classroom_path(@classroom)
  end

  def load_members_student_management!
    @membership_status_filter = "active"
    @student_memberships = @classroom.classroom_memberships
      .student
      .includes(:user)
      .where(status: "active")
      .order(:created_at, :id)
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

  def mark_managed_student_messages_read
    return 0 unless current_user.admin? || current_user.teacher?

    mark_unread_student_messages_read_for(@classroom, @student)
  end

  def load_student_profile_permissions!
    @can_manage_student = policy(@classroom).manage_members?
    @student_active_in_classroom = active_student_in_classroom?
    @can_create_compliment = policy(@classroom).create_compliment? && @student_active_in_classroom
    @can_draw_coupon = policy(@classroom).draw_coupon?
    @student_messages_enabled = @classroom.student_messages_enabled?
  end

  def active_student_in_classroom?
    @classroom.classroom_memberships.exists?(
      user_id: @student.id,
      role: "student",
      status: "active"
    )
  end
end
