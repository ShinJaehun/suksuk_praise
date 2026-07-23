class Classrooms::MembersController < ApplicationController
  MEMBER_STATUS_FILTERS = %w[active inactive all].freeze

  before_action :authenticate_user!
  before_action :set_classroom

  def show
    authorize @classroom, :manage_members?
    load_members_page!
  end

  def edit_student_names
    authorize @classroom, :manage_members?
    @member_status = member_status_filter
    load_student_name_memberships

    render :edit_student_names, layout: false
  end

  def update_student_names
    authorize @classroom, :manage_members?

    @submitted_student_names = student_name_params
    memberships_by_id = @classroom.classroom_memberships
      .student
      .includes(:user)
      .where(id: @submitted_student_names.keys)
      .index_by { |membership| membership.id.to_s }

    unless memberships_by_id.keys.sort == @submitted_student_names.keys.uniq.sort
      @student_name_errors_by_membership_id = {}
      load_student_name_memberships
      return render_student_name_errors(:invalid_membership)
    end

    @student_name_errors_by_membership_id = validate_student_names(memberships_by_id)
    if @student_name_errors_by_membership_id.any?
      load_student_name_memberships
      return render_student_name_errors(:failure)
    end

    ApplicationRecord.transaction do
      memberships_by_id.each_value { |membership| membership.user.save! }
    end

    respond_to do |format|
      format.html do
        redirect_to members_redirect_path,
          notice: t("students.members.update_names.success"),
          status: :see_other
      end
      format.turbo_stream do
        load_members_page!
        flash.now[:notice] = t("students.members.update_names.success")
        render :update_student_names, layout: false
      end
    end
  end

  def edit_student_pin
    authorize @classroom, :manage_members?
    @student_pin = ""

    render :edit_student_pin, layout: false
  end

  def update_student_pin
    authorize @classroom, :manage_members?

    @student_pin = params[:student_pin].to_s
    @student_pin_error = student_pin_error_message(@student_pin)
    return render_student_pin_error if @student_pin_error.present?

    memberships = active_student_memberships.to_a
    if memberships.empty?
      @student_pin_error = t("students.members.pin_reset.no_active_students")
      return render_student_pin_error
    end

    ApplicationRecord.transaction do
      memberships.each { |membership| membership.user.update!(student_pin: @student_pin) }
    end

    respond_to do |format|
      format.html do
        redirect_to classroom_members_path(@classroom),
          notice: t("students.members.pin_reset.success", count: memberships.size),
          status: :see_other
      end
      format.turbo_stream do
        flash.now[:notice] = t("students.members.pin_reset.success", count: memberships.size)
        render :update_student_pin, layout: false
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @student_pin_error = t(
      "students.members.pin_reset.failure",
      detail: e.record.errors.full_messages.to_sentence
    )
    render_student_pin_error
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def load_student_memberships
    @member_status = member_status_filter
    base_scope = @classroom.classroom_memberships.student
    status_counts = base_scope.group(:status).count
    @student_member_counts = {
      "active" => status_counts.fetch("active", 0),
      "inactive" => status_counts.fetch("inactive", 0)
    }
    @student_member_counts["all"] = @student_member_counts.values.sum

    @student_memberships = base_scope
      .includes(:user)
      .order(:status, :created_at, :id)
    @student_memberships = @student_memberships.where(status: @member_status) unless @member_status == "all"
  end

  def load_members_page!
    load_student_memberships
  end

  def member_status_filter
    params[:status].to_s.presence_in(MEMBER_STATUS_FILTERS) || "active"
  end

  def active_student_memberships
    @classroom.classroom_memberships
      .student
      .active
      .includes(:user)
      .order(:created_at, :id)
  end

  def load_student_name_memberships
    @member_status ||= member_status_filter
    @student_name_memberships = @classroom.classroom_memberships
      .student
      .includes(:user)
      .order(:created_at, :id)
  end

  def student_pin_error_message(pin)
    return t("students.members.pin_reset.blank") if pin.blank?
    return t("students.members.pin_reset.invalid") unless pin.match?(/\A\d{4}\z/)

    nil
  end

  def render_student_pin_error
    respond_to do |format|
      format.html do
        flash.now[:alert] = @student_pin_error
        render :edit_student_pin, status: :unprocessable_entity
      end
      format.turbo_stream do
        flash.now[:alert] = @student_pin_error
        render :edit_student_pin, formats: :html, layout: false, status: :unprocessable_entity
      end
    end
  end

  def render_student_name_errors(error_key)
    respond_to do |format|
      format.html do
        flash.now[:alert] = t("students.members.update_names.#{error_key}")
        render :edit_student_names, status: :unprocessable_entity, layout: false
      end
      format.turbo_stream do
        flash.now[:alert] = t("students.members.update_names.#{error_key}")
        render :edit_student_names, formats: :html, status: :unprocessable_entity, layout: false
      end
    end
  end

  def members_redirect_path
    return classroom_members_path(@classroom, status: member_status_filter) if params.key?(:status)

    classroom_members_path(@classroom)
  end

  def student_name_params
    raw_students = params.fetch(:students, {})
    raw_students = raw_students.to_unsafe_h if raw_students.respond_to?(:to_unsafe_h)

    raw_students.each_with_object({}) do |(membership_id, attrs), result|
      attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
      attrs = attrs.to_h if attrs.respond_to?(:to_h)
      attrs = {} unless attrs.respond_to?(:fetch)
      result[membership_id.to_s] = attrs.fetch("name", "").to_s
    end
  end

  def validate_student_names(memberships_by_id)
    memberships_by_id.each_with_object({}) do |(membership_id, membership), errors|
      membership.user.name = @submitted_student_names.fetch(membership_id)
      next if membership.user.valid?

      errors[membership_id] = t(
        "students.members.update_names.row_error",
        detail: membership.user.errors.full_messages.to_sentence
      )
    end
  end

end
