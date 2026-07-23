class ClassroomStudentsController < ApplicationController
  include UserShowDataLoader
  include StudentWeeklyDashboardLoader
  include ActionView::RecordIdentifier

  MAX_BULK_STUDENTS = 30
  helper_method :return_to_context

  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_manage!, only: [:new, :create, :bulk_new, :bulk_preview, :bulk_create]
  before_action :set_student, only: [:show, :dashboard, :activity, :coupon_assignment, :edit, :update, :destroy, :deactivate, :reactivate]
  before_action :authorize_student_data!, only: [:show, :dashboard, :activity]
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

  def bulk_preview
    if params[:back].present?
      return render_bulk_setup(status: :ok)
    end

    error_message = bulk_setup_error_message
    return render_bulk_setup(error_message: error_message, status: :unprocessable_entity) if error_message.present?

    @student_drafts = build_student_drafts

    render partial: "classroom_students/bulk_preview",
      locals: {
        classroom: @classroom,
        return_to: return_to_context,
        student_pin: bulk_student_pin,
        student_drafts: @student_drafts,
        boy_count: bulk_boy_count,
        girl_count: bulk_girl_count,
        error_message: nil,
        draft_errors: {}
      },
      status: :ok
  end

  def bulk_create
    @student_drafts = submitted_student_drafts
    created = []
    error_message, draft_errors = validate_student_drafts(@student_drafts)
    return render_bulk_preview_error(error_message, draft_errors) if error_message.present?

    student_pin = bulk_student_pin

    ApplicationRecord.transaction do
      @student_drafts.each do |draft|
        attrs = {
          name: draft[:name],
          role: "student",
          points: 0,
          gender: draft[:gender],
          avatar_key: draft[:avatar_key]
        }
        attrs[:student_pin] = student_pin
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
    render_bulk_preview_error(message, {})
  end

  def show
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

  def destroy
    authorize @classroom, :manage_members?
    student_membership.inactive!

    redirect_to classroom_members_path(@classroom),
      notice: t("students.deactivate.success"),
      status: :see_other
  end

  def deactivate
    authorize @classroom, :manage_members?
    student_membership.inactive!

    redirect_to classroom_members_path(@classroom),
      notice: t("students.deactivate.success"),
      status: :see_other
  end

  def reactivate
    authorize @classroom, :manage_members?
    student_membership.active!

    redirect_to classroom_members_path(@classroom),
      notice: t("students.reactivate.success"),
      status: :see_other
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to classroom_members_path(@classroom),
      alert: t("students.reactivate.active_membership_conflict"),
      status: :see_other
  end

  private
  
  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def user_params
    params.require(:user).permit(:name, :student_pin, :gender)
  end

  def set_student
    @student = User.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @student.student?
    raise ActiveRecord::RecordNotFound unless @classroom.classroom_memberships.exists?(
      user_id: @student.id,
      role: "student"
    )
  end

  def authorize_student_data!
    authorize @classroom, :view_student_data?
    authorize @student, :show?
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
    params.require(:user).permit(:name, :student_pin, :gender, :avatar_key).tap do |permitted|
      permitted.delete(:student_pin) if permitted[:student_pin].blank?
    end
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
    return classroom_members_path(@classroom) if members_return_to?

    classroom_path(@classroom)
  end

  def load_members_student_management!
    base_scope = @classroom.classroom_memberships.student
    status_counts = base_scope.group(:status).count
    @member_status = "active"
    @student_member_counts = {
      "active" => status_counts.fetch("active", 0),
      "inactive" => status_counts.fetch("inactive", 0)
    }
    @student_member_counts["all"] = @student_member_counts.values.sum

    @student_memberships = base_scope
      .includes(:user)
      .where(status: @member_status)
      .order(:status, :created_at, :id)
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

  def bulk_boy_count
    params[:boy_count].to_i
  end

  def bulk_girl_count
    params[:girl_count].to_i
  end

  def bulk_student_pin
    params[:student_pin].to_s.strip
  end

  def bulk_setup_error_message
    return t("students.bulk_create.errors.invalid_count") unless bulk_count_param_valid?(:boy_count) && bulk_count_param_valid?(:girl_count)
    return t("students.bulk_create.errors.empty") if bulk_setup_count.zero?
    return t("students.bulk_create.errors.too_many", count: MAX_BULK_STUDENTS) if exceeds_bulk_limit?(bulk_setup_count)
    return t("students.bulk_create.errors.invalid_pin") unless bulk_student_pin.match?(/\A\d{4}\z/)

    nil
  end

  def bulk_setup_count
    bulk_boy_count + bulk_girl_count
  end

  def bulk_count_param_valid?(key)
    params[key].to_s.match?(/\A\d+\z/)
  end

  def exceeds_bulk_limit?(new_count)
    @classroom.classroom_memberships.student.active.count + new_count > MAX_BULK_STUDENTS
  end

  def build_student_drafts
    used_avatar_keys = used_avatar_keys_in_classroom

    (Array.new(bulk_boy_count, "boy") + Array.new(bulk_girl_count, "girl")).each_with_index.map do |gender, index|
      avatar_key = pick_avatar_key(gender, used_avatar_keys)
      used_avatar_keys << avatar_key if avatar_key.present?
      { index: index.to_s, name: "", gender: gender, avatar_key: avatar_key }
    end
  end

  def submitted_student_drafts
    raw_students = params.fetch(:students, {})
    raw_students = raw_students.to_unsafe_h if raw_students.respond_to?(:to_unsafe_h)

    raw_students.each_with_index.map do |(index, attrs), fallback_index|
      attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
      attrs = attrs.to_h if attrs.respond_to?(:to_h)
      attrs = {} unless attrs.respond_to?(:fetch)
      {
        index: index.presence || fallback_index.to_s,
        name: attrs.fetch("name", "").to_s,
        gender: attrs.fetch("gender", "").to_s,
        avatar_key: attrs.fetch("avatar_key", "").to_s
      }
    end
  end

  def validate_student_drafts(drafts)
    errors = {}
    errors[:base] = t("students.bulk_create.errors.empty") if drafts.empty?
    errors[:base] = t("students.bulk_create.errors.too_many", count: MAX_BULK_STUDENTS) if exceeds_bulk_limit?(drafts.size)
    errors[:base] = t("students.bulk_create.errors.invalid_pin") unless bulk_student_pin.match?(/\A\d{4}\z/)

    drafts.each do |draft|
      row_errors = []
      row_errors << t("students.bulk_create.errors.name_required") if draft[:name].blank?
      row_errors << t("students.bulk_create.errors.invalid_avatar") unless valid_student_avatar?(draft[:gender], draft[:avatar_key])
      errors[draft[:index]] = row_errors.join(", ") if row_errors.any?
    end

    [errors[:base] || errors.values.first, errors.except(:base)]
  end

  def valid_student_avatar?(gender, avatar_key)
    User.avatar_keys_for_role("student").include?(avatar_key) &&
      User.avatar_keys_for(gender).include?(avatar_key)
  end

  def render_bulk_setup(error_message: nil, status: :ok)
    render partial: "classroom_students/bulk_form",
      locals: {
        classroom: @classroom,
        return_to: return_to_context,
        error_message: error_message,
        boy_count: params[:boy_count],
        girl_count: params[:girl_count],
        student_pin: bulk_student_pin
      },
      status: status
  end

  def render_bulk_preview_error(error_message, draft_errors)
    respond_to do |f|
      f.html { redirect_to create_success_path, alert: error_message, status: :see_other }
      f.turbo_stream do
        flash.now[:alert] = error_message
        @draft_errors = draft_errors
        render :bulk_create_error, layout: "application", status: :unprocessable_entity
      end
    end
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
