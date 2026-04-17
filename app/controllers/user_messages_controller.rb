class UserMessagesController < ApplicationController
  include UserShowDataLoader
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_user

  def create
    replied_message = find_repliable_root_message
    return redirect_to_invalid_reply unless replied_message

    @message = UserMessage.new(
      classroom: replied_message.classroom,
      sender: current_user,
      recipient: replied_message.sender,
      parent_message: replied_message,
      body: message_params[:body]
    )
    authorize @message

    if @message.save
      load_self_message_section!

      respond_to do |format|
        format.html { redirect_to user_path(@user), notice: "답장을 전송했습니다.", status: :see_other }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to user_path(@user), alert: @message.errors.full_messages.to_sentence, status: :see_other }
        format.turbo_stream do
          load_self_message_section!(reply_message: @message, active_reply_thread_id: replied_message.id)
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
    message = current_user.received_messages
      .root_messages
      .includes(:sender)
      .find_by(id: params[:reply_to_message_id])

    return nil unless message
    return nil if message.sender.student?

    message
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

  def load_self_message_section!(reply_message: nil, active_reply_thread_id: nil)
    load_user_show_data!(
      user: @user,
      classroom: nil,
      include_recent_issued: true,
      recent_in_classroom: false
    )

    @reply_message = reply_message || UserMessage.new
    @active_reply_thread_id = active_reply_thread_id
    @message_section_dom_id = dom_id(@user, :message_section)
  end
end
