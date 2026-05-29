class Classrooms::MembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom

  def show
    authorize @classroom, :update?
    load_teacher_assignment_form if current_user.admin?
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def load_teacher_assignment_form
    @assignable_teachers = User.teacher.order(:name, :id)
    @assigned_teacher_ids = @classroom.classroom_memberships.teacher.pluck(:user_id)
  end
end
