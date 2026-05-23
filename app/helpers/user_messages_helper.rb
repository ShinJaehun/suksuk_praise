module UserMessagesHelper
  def user_message_sender_label(message)
    return "나" if message.sender == current_user
    return "관리자" if message.sender.admin?
    return "선생님" if message.sender.teacher?

    "학생"
  end

  def show_user_message_reply_form?(message, user)
    return false unless user.present? && message.parent_message_id.nil?

    if current_user.student?
      current_user == user && [message.sender_id, message.recipient_id].include?(user.id)
    elsif current_user.teacher? || current_user.admin?
      user.student? && [message.sender_id, message.recipient_id].include?(user.id)
    else
      false
    end
  end
end
