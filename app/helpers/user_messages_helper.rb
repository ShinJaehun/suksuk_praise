module UserMessagesHelper
  def user_message_sender_label(message)
    return "나" if message.sender == current_user
    return "관리자" if message.sender.admin?
    return "선생님" if message.sender.teacher?

    "학생"
  end

  def show_user_message_reply_form?(message, user)
    user.present? &&
      current_user == user &&
      message.recipient_id == user.id &&
      message.parent_message_id.nil? &&
      !message.sender.student?
  end
end
