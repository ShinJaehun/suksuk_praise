class StudentSessionsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def new
    load_classroom
    set_student_session_form_url
    load_students if @classroom
  end

  def create
    load_classroom
    set_student_session_form_url
    load_students

    student = find_student_for_pin_login
    if student&.student_pin_configured? && student.authenticate_student_pin(params[:student_pin].to_s)
      classroom_id = @classroom.id

      sign_out(:user) if user_signed_in?
      reset_session

      sign_in(:user, student)
      session[:student_login_classroom_id] = classroom_id
      session[:student_last_seen_at] = Time.current.to_i
      redirect_to student_landing_path(student), notice: '로그인했습니다.'
    else
      flash.now[:alert] = '교실, 학생, PIN을 확인해 주세요.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    classroom_id = session.delete(:student_login_classroom_id)
    session.delete(:student_last_seen_at)
    sign_out(:user) if current_user&.student?
    redirect_to student_logout_redirect_path(classroom_id), notice: '사용을 끝냈습니다.'
  end

  private

  def load_classroom
    @classroom =
      if params[:student_login_token].present?
        Classroom.find_by!(student_login_token: params[:student_login_token])
      elsif params[:classroom_id].present?
        Classroom.find(params[:classroom_id])
      end
  end

  def set_student_session_form_url
    @student_session_form_url =
      if params[:student_login_token].present?
        public_student_login_path(student_login_token: params[:student_login_token])
      elsif @classroom
        classroom_student_login_path(@classroom)
      else
        new_student_session_path
      end
  end

  def load_students
    @students = @classroom&.students&.order(:name) || User.none
  end

  def find_student_for_pin_login
    return nil unless @classroom

    student = User.find_by(id: params[:student_id])
    return nil unless student&.student?
    return nil unless @classroom.classroom_memberships.exists?(user_id: student.id, role: 'student')

    student
  end

  def student_landing_path(student)
    return classroom_student_path(@classroom, student) if @classroom

    user_path(student)
  end

  def student_logout_redirect_path(classroom_id)
    return new_student_session_path if classroom_id.blank?
    return new_student_session_path unless Classroom.exists?(id: classroom_id)

    classroom_student_login_path(classroom_id)
  end
end
