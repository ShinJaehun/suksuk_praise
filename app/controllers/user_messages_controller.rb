class UserMessagesController < ApplicationController
  include UserShowDataLoader
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_user

  def create
    replied_message = find_repliable_root_message if params[:reply_to_message_id].present?
    return redirect_to_invalid_reply if params[:reply_to_message_id].present? && !replied_message

    @message = replied_message ? build_reply_message(replied_message) : build_first_root_message

    if replied_message ? save_reply_message : save_root_messages
      broadcast_student_card_alerts_for(@message.classroom, @message.sender) if @message.sender.student?
      load_self_message_section!

      respond_to do |format|
        format.html { redirect_to user_path(@user), notice: "답장을 전송했습니다.", status: :see_other }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to user_path(@user), alert: @message.errors.full_messages.to_sentence, status: :see_other }
        format.turbo_stream do
          load_self_message_section!(
            root_message: replied_message ? UserMessage.new : @message,
            reply_message: replied_message ? @message : UserMessage.new,
            active_reply_thread_id: replied_message&.id
          )
          render :create, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
    authorize @user, :show?
    raise ActiveRecord::RecordNotFound unless current_user == @user && @user.student?
  end

  def find_repliable_root_message
    message = UserMessage
      .root_messages
      .includes(:sender)
      .where("sender_id = :id OR recipient_id = :id", id: current_user.id)
      .find_by(id: params[:reply_to_message_id])

    return nil unless message

    message
  end

  def build_reply_message(replied_message)
    UserMessage.new(
      classroom: replied_message.classroom,
      sender: current_user,
      recipient: reply_recipient_for(replied_message),
      parent_message: replied_message,
      body: message_params[:body]
    )
  end

  def reply_recipient_for(replied_message)
    replied_message.sender_id == current_user.id ? replied_message.recipient : replied_message.sender
  end

  def build_first_root_message
    classroom = classroom_for_student_root_message
    recipient = classroom_teachers_for(classroom).first

    UserMessage.new(
      classroom: classroom,
      sender: current_user,
      recipient: recipient,
      body: message_params[:body]
    )
  end

  def classroom_for_student_root_message
    classroom_ids = current_user.classroom_memberships.where(role: "student").select(:classroom_id)
    Classroom
      .where(
        id: classroom_ids,
        student_initiated_messages_enabled: true
      )
      .order(:id)
      .first
  end

  def save_reply_message
    authorize @message
    @message.save
  end

  def save_root_messages
    root_messages = root_messages_for_classroom
    @message = root_messages.first || @message

    if root_messages.empty?
      @message.errors.add(:base, "메시지를 받을 선생님이 없습니다.")
      return false
    end

    root_messages.each { |message| authorize message }

    UserMessage.transaction do
      root_messages.each(&:save!)
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    @message = e.record if e.record.is_a?(UserMessage)
    false
  end

  def root_messages_for_classroom
    classroom = classroom_for_student_root_message

    classroom_teachers_for(classroom).map do |teacher|
      UserMessage.new(
        classroom: classroom,
        sender: current_user,
        recipient: teacher,
        body: message_params[:body]
      )
    end
  end

  def classroom_teachers_for(classroom)
    return User.none if classroom.blank?

    User.teacher
      .joins(:classroom_memberships)
      .where(classroom_memberships: { classroom_id: classroom.id, role: "teacher" })
      .distinct
      .order(:name, :id)
  end

  def redirect_to_invalid_reply
    respond_to do |format|
      format.html { redirect_to user_path(@user), alert: "응답할 수 없는 메시지입니다.", status: :see_other }
      format.turbo_stream do
        invalid_reply_message = UserMessage.new
        invalid_reply_message.errors.add(:base, "응답할 수 없는 메시지입니다.")
        load_self_message_section!(
          reply_message: invalid_reply_message,
          active_reply_thread_id: params[:reply_to_message_id].presence&.to_i
        )
        render :create, status: :unprocessable_entity
      end
    end
  end

  def message_params
    params.require(:user_message).permit(:body)
  end

  def load_self_message_section!(root_message: nil, reply_message: nil, active_reply_thread_id: nil)
    load_user_show_data!(
      user: @user,
      classroom: nil,
      include_recent_issued: true,
      recent_in_classroom: false
    )

    @new_message = root_message || UserMessage.new
    @reply_message = reply_message || UserMessage.new
    @active_reply_thread_id = active_reply_thread_id
    @message_section_dom_id = dom_id(@user, :message_section)
    @message_teacher_options = message_teacher_options
  end

  def message_teacher_options
    classroom_ids = current_user.classroom_memberships.where(role: "student").select(:classroom_id)
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
