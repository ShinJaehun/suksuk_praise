class UsersController < ApplicationController
  include UserShowDataLoader
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_user, only: [:show]

  def show
    authorize @user, :show?
    redirect_student_self_to_classroom_context! and return if @user.student? && current_user == @user
    redirect_to_managed_student_page! and return if @user.student? && current_user != @user

    @can_create_compliment = false
    @can_draw_coupon = false
    @visible_classrooms = @user.classrooms.order(created_at: :asc)

    load_user_show_data!(
      user: @user,
      classroom: nil,
      include_recent_issued: true,
      recent_in_classroom: false
    )

    @reply_message = UserMessage.new
    @new_message = UserMessage.new
    @message_teacher_options = message_teacher_options
    @message_section_dom_id = dom_id(@user, :message_section)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def redirect_to_managed_student_page!
    classroom = managed_page_classroom_for(@user)
    raise ActiveRecord::RecordNotFound unless classroom

    redirect_to classroom_student_path(classroom, @user)
  end

  def managed_page_classroom_for(user)
    return user.classrooms.order(created_at: :asc).first if current_user.admin?
    return teacher_managed_classroom_for(user) if current_user.teacher?

    nil
  end

  def redirect_student_self_to_classroom_context!
    classroom = student_self_page_classroom_for(@user)
    return unless classroom

    redirect_to classroom_student_path(classroom, @user)
  end

  def student_self_page_classroom_for(user)
    session_classroom = session_classroom_for(user)
    return session_classroom if session_classroom

    user.classrooms.order(created_at: :asc).first
  end

  def session_classroom_for(user)
    classroom_id = session[:student_login_classroom_id]
    return nil if classroom_id.blank?

    user.classrooms.where(id: classroom_id).first
  end

  def teacher_managed_classroom_for(user)
    Classroom
      .joins(:classroom_memberships)
      .where(classroom_memberships: { user_id: current_user.id, role: "teacher" })
      .where(id: user.classroom_ids)
      .order(created_at: :asc)
      .first
  end

  def message_teacher_options
    return User.none unless @user.student?

    classroom_ids = @user.classroom_memberships.where(role: "student").select(:classroom_id)
    User.teacher
      .joins(classroom_memberships: :classroom)
      .where(
        classrooms: { student_initiated_messages_enabled: true },
        classroom_memberships: { classroom_id: classroom_ids, role: "teacher" }
      )
      .distinct
      .order(:name, :id)
  end
end
