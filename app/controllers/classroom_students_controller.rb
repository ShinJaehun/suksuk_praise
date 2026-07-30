class ClassroomStudentsController < ApplicationController
  include UserShowDataLoader
  include StudentWeeklyDashboardLoader
  include ActionView::RecordIdentifier

  helper_method :return_to_context

  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_manage!, only: [:new, :create]
  before_action :set_student, only: [:show, :dashboard, :activity, :coupon_assignment, :edit, :update, :destroy, :deactivate, :reactivate]
  before_action :ensure_active_self_student!, only: [:show, :dashboard, :activity, :edit, :update]
  before_action :authorize_student_data!, only: [:show, :dashboard, :activity]

  def new
    @user = User.new
    @student_membership = @classroom.classroom_memberships.build(role: "student", status: "active")
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
    @student_membership = @classroom.classroom_memberships.build(
      user: @user,
      role: "student",
      status: "active",
      student_number: submitted_student_number
    )
    validate_new_student_pin!
    validate_student_avatar_params!(@user, attrs)
    validate_new_student_number!

    if @user.errors.empty? && @student_membership.errors.empty? && save_student_with_membership
      respond_to do |f|
        f.html { redirect_to create_success_path, notice: t("students.create.success"), status: :see_other }
        f.turbo_stream do
          flash.now[:notice] = t("students.create.success")
          if members_return_to?
            load_members_student_management!
            render :create_for_members, layout: "application"
          else
            load_classroom_student_grid!
            render :create, layout: "application"
          end
        end
      end
    else
      message = (@user.errors.full_messages + @student_membership.errors.full_messages).to_sentence.presence ||
        t("students.create.failure_fallback")

      respond_to do |f|
        f.html do
          flash.now[:alert] = message
          render partial: "classroom_students/form",
            locals: { classroom: @classroom, user: @user, return_to: return_to_context },
            status: :unprocessable_entity
        end
        f.turbo_stream do
          flash.now[:alert] = message
          render "classroom_students/create_error", layout: "application",
            status: :unprocessable_entity
        end
      end
    end
  end

  def show
    @user = @student
    load_student_profile_permissions!
    @open_coupon_assignment = @can_issue_coupon && params[:open_coupon_assignment] == "1"
    read_count = @student_messages_enabled ? mark_managed_student_messages_read : 0

    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: false,
      recent_in_classroom: true
    )
    @pending_coupon_use_request_count = @pending_coupon_use_requests_by_coupon_id.size

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
    if current_user.student?
      authorize @student, :manage_own_student_pin?
      load_student_self_pin_form!
    else
      authorize @classroom, :manage_members?
      load_student_edit_form!
    end
  end

  def update
    if current_user.student?
      authorize @student, :manage_own_student_pin?
      update_own_student_pin
      return
    end

    authorize @classroom, :manage_members?
    load_student_edit_form!
    attrs = managed_student_params
    attrs.delete(:avatar_key) if retained_current_avatar_after_gender_change?(attrs)
    if reassign_avatar_key?(attrs)
      attrs[:avatar_key] = pick_avatar_key(attrs[:gender], used_avatar_keys_in_classroom(excluding: @student))
    end

    if update_managed_student(attrs)
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
    reactivate_error = nil

    @classroom.with_lock do
      @student.with_lock do
        membership = student_membership.reload

        if active_student_membership_in_other_classroom?
          reactivate_error = t("students.reactivate.active_membership_conflict")
          next
        end

        if active_student_limit_exceeded?(membership.active? ? 0 : 1)
          reactivate_error = t("students.reactivate.too_many", count: Classroom::MAX_ACTIVE_STUDENTS)
          next
        end

        membership.active! unless membership.active?
      end
    end

    if reactivate_error.present?
      redirect_to classroom_members_path(@classroom),
        alert: reactivate_error,
        status: :see_other
      return
    end

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

  def load_student_self_pin_form!
    @user = @student
    @student_membership = student_membership
    @student_self_pin_edit = true
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

  def student_self_pin_params
    params.require(:user).permit(:student_pin, :student_pin_confirmation)
  end

  def classroom_membership_params
    params.fetch(:classroom_membership, ActionController::Parameters.new)
      .permit(:student_number)
  end

  def submitted_student_number
    classroom_membership_params[:student_number]
  end

  def managed_student_number_submitted?
    params.key?(:classroom_membership)
  end

  def update_own_student_pin
    load_student_self_pin_form!
    attrs = student_self_pin_params
    pin = attrs[:student_pin].to_s
    confirmation = attrs[:student_pin_confirmation].to_s

    if pin.blank?
      @student.errors.add(:base, t("students.edit.self_pin.errors.blank"))
    elsif !pin.match?(/\A\d{4}\z/)
      @student.errors.add(:base, t("students.edit.self_pin.errors.invalid"))
    elsif pin != confirmation
      @student.errors.add(:base, t("students.edit.self_pin.errors.confirmation"))
    end

    if @student.errors.empty? && @student.update(attrs)
      redirect_to classroom_student_path(@classroom, @student),
        notice: t("students.edit.self_pin.success"),
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
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
      .where(status: @member_status)
      .in_roster_order
      .preload(:user)
  end

  def load_classroom_student_grid!
    @student_memberships = @classroom.classroom_memberships
      .student
      .active
      .in_roster_order
      .preload(:user)
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

  def active_student_limit_exceeded?(new_count)
    @classroom.active_student_memberships_count + new_count > Classroom::MAX_ACTIVE_STUDENTS
  end

  def active_student_limit_error
    t("students.bulk_create.errors.too_many", count: Classroom::MAX_ACTIVE_STUDENTS)
  end

  def student_avatar_matches_gender?(gender, avatar_key)
    User.avatar_keys_for_role("student").include?(avatar_key) &&
      User.avatar_keys_for(gender).include?(avatar_key)
  end

  def validate_new_student_pin!
    return if @user.student_pin.to_s.match?(/\A\d{4}\z/)

    @user.errors.add(:student_pin, t("students.create.errors.invalid_pin"))
  end

  def validate_new_student_number!
    return if submitted_student_number.present?

    @student_membership.errors.add(
      :student_number,
      t("students.create.errors.student_number_required")
    )
  end

  def validate_student_avatar_params!(user, attrs)
    return if attrs[:gender].blank? || attrs[:avatar_key].blank?
    return if student_avatar_matches_gender?(attrs[:gender], attrs[:avatar_key])

    user.errors.add(:avatar_key, t("students.create.errors.invalid_avatar"))
  end

  def validate_managed_student_avatar_params!(attrs)
    avatar_key = attrs[:avatar_key]
    return if avatar_key.blank?

    gender = attrs[:gender].presence || @student.gender
    return if gender.blank?
    return if student_avatar_matches_gender?(gender, avatar_key)

    @student.errors.add(:avatar_key, t("students.create.errors.invalid_avatar"))
  end

  def retained_current_avatar_after_gender_change?(attrs)
    attrs[:gender].present? &&
      attrs[:gender] != @student.gender &&
      attrs[:avatar_key].present? &&
      attrs[:avatar_key] == @student.avatar_key &&
      !student_avatar_matches_gender?(attrs[:gender], attrs[:avatar_key])
  end

  def save_student_with_membership
    saved = false

    @classroom.with_lock do
      if active_student_limit_exceeded?(1)
        @user.errors.add(:base, active_student_limit_error)
        next
      end

      @user.save!
      @student_membership.user = @user
      @student_membership.save!
      saved = true
    end

    saved
  rescue ActiveRecord::RecordInvalid => e
    if e.record == @student_membership
      normalize_student_number_errors!
    elsif e.record != @user
      @user.errors.add(:base, e.record.errors.full_messages.to_sentence)
    end
    false
  rescue ActiveRecord::RecordNotUnique
    add_student_number_taken_error!
    false
  end

  def update_managed_student(attrs)
    @student.assign_attributes(attrs)
    if managed_student_number_submitted?
      @student_membership.student_number = submitted_student_number.presence
    end

    student_valid = @student.valid?
    membership_valid = !managed_student_number_submitted? || @student_membership.valid?
    validate_managed_student_avatar_params!(attrs)
    normalize_student_number_errors! unless membership_valid
    return false unless student_valid && membership_valid && @student.errors.empty?

    ClassroomMembership.transaction do
      @student_membership.save! if managed_student_number_submitted?
      @student.save!
    end
    true
  rescue ActiveRecord::RecordInvalid
    normalize_student_number_errors! if @student_membership.errors.any?
    false
  rescue ActiveRecord::RecordNotUnique
    add_student_number_taken_error!
    false
  end

  def normalize_student_number_errors!
    return if @student_membership.errors[:student_number].empty?

    value = @student_membership.student_number_before_type_cast
    message =
      if value.to_s.match?(/\A[1-9]\d*\z/)
        t("students.create.errors.student_number_taken", number: value)
      else
        t("students.create.errors.student_number_invalid")
      end
    @student_membership.errors.delete(:student_number)
    @student_membership.errors.add(:student_number, message)
  end

  def add_student_number_taken_error!
    value = @student_membership.student_number_before_type_cast
    @student_membership.errors.add(
      :student_number,
      t("students.create.errors.student_number_taken", number: value)
    )
  end

  def reassign_avatar_key?(attrs)
    return false if attrs[:avatar_key].present?

    attrs[:gender].present? &&
      attrs[:gender] != @student.gender &&
      !@student.avatar.attached?
  end

  def active_student_membership_in_other_classroom?
    ClassroomMembership.student.active
      .where(user_id: @student.id)
      .where.not(classroom_id: @classroom.id)
      .exists?
  end

  def mark_managed_student_messages_read
    return 0 unless current_user.admin? || current_user.active_teacher?

    mark_unread_student_messages_read_for(@classroom, @student)
  end

  def load_student_profile_permissions!
    @can_manage_student = policy(@classroom).manage_members?
    @student_active_in_classroom = active_student_in_classroom?
    @can_manage_own_student_pin =
      policy(@student).manage_own_student_pin? && @student_active_in_classroom
    @can_create_compliment = policy(@classroom).create_compliment? && @student_active_in_classroom
    @can_draw_coupon = policy(@classroom).draw_coupon?
    @can_issue_coupon = @can_draw_coupon && @student_active_in_classroom
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
