class Classrooms::MembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom

  def show
    authorize @classroom, :manage_members?
    load_members_page!
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
      load_members_page!
      flash.now[:alert] = t("students.members.update_names.invalid_membership")
      return render :show, status: :unprocessable_entity
    end

    @student_name_errors_by_membership_id = validate_student_names(memberships_by_id)
    if @student_name_errors_by_membership_id.any?
      load_members_page!
      flash.now[:alert] = t("students.members.update_names.failure")
      return render :show, status: :unprocessable_entity
    end

    ApplicationRecord.transaction do
      memberships_by_id.each_value { |membership| membership.user.save! }
    end

    redirect_to classroom_members_path(@classroom, status: normalized_status_filter),
      notice: t("students.members.update_names.success"),
      status: :see_other
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def load_student_memberships
    @membership_status_filter = normalized_status_filter
    @student_memberships = @classroom.classroom_memberships
      .student
      .includes(:user)
      .order(:created_at, :id)
    @student_memberships = @student_memberships.where(status: @membership_status_filter) unless @membership_status_filter == "all"
  end

  def normalized_status_filter
    params[:status].presence_in(%w[active inactive all]) || "active"
  end

  def load_members_page!
    load_student_memberships
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
