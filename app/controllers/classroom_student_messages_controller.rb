class ClassroomStudentMessagesController < ApplicationController
  include UserShowDataLoader
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_classroom
  before_action :set_student
  before_action :ensure_active_self_student!, only: :index
  before_action :ensure_active_student!, only: :create

  def index
    authorize @student, :show?
    raise Pundit::NotAuthorizedError unless @classroom.student_messages_enabled?

    read_count = mark_managed_student_messages_read
    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: false,
      recent_in_classroom: true
    )

    @user = @student
    @new_message = UserMessage.new
    @reply_message = UserMessage.new
    @message_teacher_options = student_message_teacher_options
    @message_section_dom_id = dom_id(@student, :message_section)
    @can_manage_student = policy(@classroom).manage_members?
    @student_active_in_classroom = active_student_in_classroom?
    @can_create_compliment = policy(@classroom).create_compliment? && @student_active_in_classroom
    @student_messages_enabled = true
    broadcast_student_card_alerts_for(@classroom, @student) if read_count.positive?
  end

  def create
    replied_message = find_repliable_student_root_message if params[:reply_to_message_id].present?
    return redirect_to_invalid_reply if params[:reply_to_message_id].present? && !replied_message

    @message = replied_message ? build_reply_message(replied_message) : build_root_message
    authorize @message

    if @message.save
      mark_unread_student_messages_read_for(@classroom, @student)
      broadcast_student_card_alerts_for(@classroom, @student)
      load_managed_message_section!

      respond_to do |format|
        format.html { redirect_to classroom_student_path(@classroom, @student), notice: "메시지를 전송했습니다.", status: :see_other }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html do
          redirect_to classroom_student_path(@classroom, @student),
            alert: @message.errors.full_messages.to_sentence,
            status: :see_other
        end
        format.turbo_stream do
          load_managed_message_section!(
            message: replied_message ? UserMessage.new : @message,
            reply_message: replied_message ? @message : UserMessage.new,
            active_reply_thread_id: replied_message&.id
          )
          render :create, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def set_student
    @student = User.find(params[:student_id])
    raise ActiveRecord::RecordNotFound unless @student.student?
    raise ActiveRecord::RecordNotFound unless @classroom.classroom_memberships.exists?(
      user_id: @student.id,
      role: "student"
    )
  end

  def ensure_active_student!
    raise ActiveRecord::RecordNotFound unless @classroom.classroom_memberships.exists?(
      user_id: @student.id,
      role: "student",
      status: "active"
    )
  end

  def ensure_active_self_student!
    return unless current_user&.student? && current_user.id == @student.id
    return if active_student_in_classroom?

    raise ActiveRecord::RecordNotFound
  end

  def active_student_in_classroom?
    @classroom.classroom_memberships.exists?(
      user_id: @student.id,
      role: "student",
      status: "active"
    )
  end

  def message_params
    params.require(:user_message).permit(:body)
  end

  def find_repliable_student_root_message
    UserMessage
      .root_messages
      .where(classroom_id: @classroom.id)
      .where("sender_id = :id OR recipient_id = :id", id: @student.id)
      .find_by(id: params[:reply_to_message_id])
  end

  def build_root_message
    UserMessage.new(
      classroom: @classroom,
      sender: current_user,
      recipient: @student,
      body: message_params[:body]
    )
  end

  def build_reply_message(replied_message)
    UserMessage.new(
      classroom: @classroom,
      sender: current_user,
      recipient: @student,
      parent_message: replied_message,
      body: message_params[:body]
    )
  end

  def redirect_to_invalid_reply
    respond_to do |format|
      format.html { redirect_to classroom_student_path(@classroom, @student), alert: "응답할 수 없는 메시지입니다.", status: :see_other }
      format.turbo_stream do
        invalid_reply_message = UserMessage.new
        invalid_reply_message.errors.add(:base, "응답할 수 없는 메시지입니다.")
        load_managed_message_section!(
          reply_message: invalid_reply_message,
          active_reply_thread_id: params[:reply_to_message_id].presence&.to_i
        )
        render :create, status: :unprocessable_entity
      end
    end
  end

  def load_managed_message_section!(message: nil, reply_message: nil, active_reply_thread_id: nil)
    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: true,
      recent_in_classroom: true
    )

    @new_message = message || UserMessage.new
    @reply_message = reply_message || UserMessage.new
    @active_reply_thread_id = active_reply_thread_id
    @message_section_dom_id = dom_id(@student, :message_section)
  end

  def student_message_teacher_options
    return User.none unless current_user == @student && @classroom.student_can_start_messages?

    User.teacher
      .joins(:classroom_memberships)
      .where(classroom_memberships: { classroom_id: @classroom.id, role: "teacher" })
      .distinct
      .order(:name, :id)
  end

  def mark_managed_student_messages_read
    return 0 unless current_user.admin? || current_user.teacher?

    mark_unread_student_messages_read_for(@classroom, @student)
  end
end
