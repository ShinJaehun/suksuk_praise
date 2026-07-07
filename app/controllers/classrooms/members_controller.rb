class Classrooms::MembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom

  def show
    authorize @classroom, :manage_members?
    load_student_memberships
    if current_user.admin?
      load_teacher_assignment_form
    end
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

  def load_teacher_assignment_form
    @assignable_teachers = User.teacher.order(:name, :id)
    @assigned_teacher_ids = @classroom.classroom_memberships
      .teacher
      .joins(:user)
      .where(users: { role: "teacher" })
      .pluck(:user_id)
  end
end
