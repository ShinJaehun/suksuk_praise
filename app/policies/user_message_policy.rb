class UserMessagePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      return scope.all if user&.admin?

      if user&.teacher?
        teacher_classroom_ids = user.classroom_memberships.where(role: "teacher").pluck(:classroom_id)
        return scope.where(classroom_id: teacher_classroom_ids)
      end

      if user&.student?
        return scope.where("sender_id = :id OR recipient_id = :id", id: user.id)
      end

      scope.none
    end
  end

  def create?
    return false unless record.classroom&.student_messages_enabled?

    return admin_message_to_student? if user&.admin?
    return teacher_message_to_managed_student? if user&.teacher?
    return student_message_to_classroom_teacher? if user&.student?

    false
  end

  def show?
    return true if user&.admin?

    if user&.teacher?
      return false unless record.classroom.present?

      return teacher_manages_classroom?(record.classroom)
    end

    if user&.student?
      return record.sender_id == user.id || record.recipient_id == user.id
    end

    false
  end

  private

  def admin_message_to_student?
    return false unless record.sender_id == user.id
    return false unless record.recipient&.student?

    return admin_reply_to_student_thread? if record.parent_message.present?
    return false unless record.parent_message_id.nil?

    student_in_classroom?(record.recipient, record.classroom)
  end

  def teacher_message_to_managed_student?
    return false unless record.sender_id == user.id
    return false unless record.recipient&.student?
    return false unless teacher_manages_classroom?(record.classroom)

    return teacher_reply_to_managed_student_thread? if record.parent_message.present?
    return false unless record.parent_message_id.nil?

    student_in_classroom?(record.recipient, record.classroom)
  end

  def admin_reply_to_student_thread?
    reply_to_managed_student_thread? && student_in_classroom?(record.recipient, record.classroom)
  end

  def teacher_reply_to_managed_student_thread?
    reply_to_managed_student_thread? && student_in_classroom?(record.recipient, record.classroom)
  end

  def reply_to_managed_student_thread?
    return false unless record.parent_message.present?
    return false unless record.parent_message.parent_message_id.nil?
    return false unless [record.parent_message.sender_id, record.parent_message.recipient_id].include?(record.recipient_id)
    return false unless [record.parent_message.sender, record.parent_message.recipient].any?(&:student?)
    return false unless record.parent_message.classroom_id == record.classroom_id

    true
  end

  def student_reply_to_existing_root_message?
    return false unless record.sender_id == user.id
    return false unless record.parent_message.present?
    return false unless record.parent_message.parent_message_id.nil?
    return false unless student_in_classroom?(user, record.classroom)
    return false unless [record.parent_message.sender_id, record.parent_message.recipient_id].include?(user.id)
    return false unless [record.parent_message.sender_id, record.parent_message.recipient_id].include?(record.recipient_id)
    return false unless record.recipient_id != user.id
    return false unless record.parent_message.classroom_id == record.classroom_id
    return false if record.recipient.teacher? && !teacher_in_classroom?(record.recipient, record.classroom)

    true
  end

  def student_message_to_classroom_teacher?
    return false unless record.sender_id == user.id
    return student_reply_to_existing_root_message? if record.parent_message.present?
    return false unless record.classroom&.student_can_start_messages?
    return false unless record.recipient&.teacher?
    return false unless student_in_classroom?(user, record.classroom)
    return false unless teacher_in_classroom?(record.recipient, record.classroom)

    true
  end

  def teacher_manages_classroom?(classroom)
    return false if classroom.blank?

    classroom.classroom_memberships.exists?(user_id: user.id, role: "teacher")
  end

  def student_in_classroom?(student, classroom)
    return false if classroom.blank? || student.blank?

    classroom.classroom_memberships.exists?(user_id: student.id, role: "student")
  end

  def teacher_in_classroom?(teacher, classroom)
    return false if classroom.blank? || teacher.blank?

    classroom.classroom_memberships.exists?(user_id: teacher.id, role: "teacher")
  end
end
