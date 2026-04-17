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
    return admin_to_student? if user&.admin?
    return teacher_to_managed_student? if user&.teacher?
    return student_reply_to_existing_root_message? if user&.student?

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

  def admin_to_student?
    return false unless record.sender_id == user.id
    return false unless record.parent_message_id.nil?
    return false unless record.recipient&.student?

    student_in_classroom?(record.recipient, record.classroom)
  end

  def teacher_to_managed_student?
    return false unless record.sender_id == user.id
    return false unless record.parent_message_id.nil?
    return false unless record.recipient&.student?
    return false unless teacher_manages_classroom?(record.classroom)

    student_in_classroom?(record.recipient, record.classroom)
  end

  def student_reply_to_existing_root_message?
    return false unless record.sender_id == user.id
    return false unless record.parent_message.present?
    return false unless record.parent_message.parent_message_id.nil?
    return false unless record.recipient&.teacher? || record.recipient&.admin?
    return false unless student_in_classroom?(user, record.classroom)
    return false unless record.parent_message.recipient_id == user.id
    return false unless record.parent_message.sender_id == record.recipient_id
    return false unless record.parent_message.classroom_id == record.classroom_id
    return false if record.recipient.teacher? && !teacher_in_classroom?(record.recipient, record.classroom)

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
