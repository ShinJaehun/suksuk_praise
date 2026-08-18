class ClassroomStudents::BulkRegistrationsController < ApplicationController
  helper_method :return_to_context

  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_manage!

  def new
    locals = {
      classroom: @classroom,
      return_to: return_to_context,
      remaining_capacity: bulk_remaining_capacity
    }
    respond_to do |format|
      format.html { render partial: "classroom_students/bulk_form", locals: locals }
      format.turbo_stream { render partial: "classroom_students/bulk_form", locals: locals }
    end
  end

  def preview
    return render_bulk_setup(status: :ok) if params[:back].present?

    result = ClassroomStudents::BulkRegistration.preview(
      classroom: @classroom,
      student_pin: bulk_student_pin,
      student_count: params[:student_count]
    )
    return render_bulk_setup(error_message: result.error, status: :unprocessable_content) unless result.success?

    @student_drafts = result.rows
    render partial: "classroom_students/bulk_preview",
      locals: {
        classroom: @classroom,
        return_to: return_to_context,
        student_pin: bulk_student_pin,
        student_drafts: @student_drafts,
        remaining_capacity: bulk_remaining_capacity,
        error_message: nil,
        draft_errors: {}
      },
      status: :ok
  end

  def create
    result = ClassroomStudents::BulkRegistration.call(
      classroom: @classroom,
      student_pin: bulk_student_pin,
      rows: params.fetch(:students, {})
    )
    @student_drafts = result.rows
    return render_bulk_preview_error(result.error, result.row_errors) unless result.success?

    message = t("students.bulk_create.success", count: result.students.size)
    respond_to do |format|
      format.html { redirect_to create_success_path, notice: message, status: :see_other }
      format.turbo_stream do
        flash.now[:notice] = message
        if members_return_to?
          load_members_student_management!
          render "classroom_students/bulk_create_for_members", layout: "application"
        else
          load_classroom_student_grid!
          render "classroom_students/bulk_create", layout: "application"
        end
      end
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
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

  def bulk_student_pin
    params[:student_pin].to_s.strip
  end

  def bulk_remaining_capacity
    [Classroom::MAX_ACTIVE_STUDENTS - @classroom.active_student_memberships_count, 0].max
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

  def render_bulk_setup(error_message: nil, status: :ok)
    render partial: "classroom_students/bulk_form",
      locals: {
        classroom: @classroom,
        return_to: return_to_context,
        error_message: error_message,
        student_count: params[:student_count],
        remaining_capacity: bulk_remaining_capacity,
        student_pin: bulk_student_pin
      },
      status: status
  end

  def render_bulk_preview_error(error_message, draft_errors)
    @bulk_remaining_capacity = bulk_remaining_capacity
    respond_to do |format|
      format.html do
        render partial: "classroom_students/bulk_preview",
          locals: {
            classroom: @classroom,
            return_to: return_to_context,
            student_pin: bulk_student_pin,
            student_drafts: @student_drafts,
            remaining_capacity: @bulk_remaining_capacity,
            error_message: error_message,
            draft_errors: draft_errors
          },
          status: :unprocessable_content
      end
      format.turbo_stream do
        flash.now[:alert] = error_message
        @draft_errors = draft_errors
        render "classroom_students/bulk_create_error",
          layout: "application",
          status: :unprocessable_content
      end
    end
  end
end
