class UsersController < ApplicationController
  include UserShowDataLoader
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_user, only: [:show]

  def show
    authorize @user, :show?
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

  def teacher_managed_classroom_for(user)
    Classroom
      .joins(:classroom_memberships)
      .where(classroom_memberships: { user_id: current_user.id, role: "teacher" })
      .where(id: user.classroom_ids)
      .order(created_at: :asc)
      .first
  end
end
