class StudentSessionsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def new
    load_classroom
    load_students if @classroom
  end

  def create
    load_classroom
    load_students

    student = find_student_for_pin_login
    if student&.student_pin_configured? && student.authenticate_student_pin(params[:student_pin].to_s)
      sign_out(:user) if user_signed_in?
      sign_in(:user, student)
      redirect_to user_path(student), notice: "로그인했습니다."
    else
      flash.now[:alert] = "교실, 학생, PIN을 확인해 주세요."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out(:user) if current_user&.student?
    redirect_to new_student_session_path, notice: "사용을 끝냈습니다."
  end

  private

  def load_classroom
    @classroom = Classroom.find_by(id: params[:classroom_id])
  end

  def load_students
    @students = @classroom&.students&.order(:name) || User.none
  end

  def find_student_for_pin_login
    return nil unless @classroom

    student = User.find_by(id: params[:student_id])
    return nil unless student&.student?
    return nil unless @classroom.classroom_memberships.exists?(user_id: student.id, role: "student")

    student
  end
end
