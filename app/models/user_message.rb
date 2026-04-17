class UserMessage < ApplicationRecord
  belongs_to :classroom
  belongs_to :sender, class_name: "User"
  belongs_to :recipient, class_name: "User"
  belongs_to :parent_message, class_name: "UserMessage", optional: true

  has_many :replies,
           -> { order(created_at: :asc) },
           class_name: "UserMessage",
           foreign_key: :parent_message_id,
           dependent: :nullify,
           inverse_of: :parent_message

  scope :root_messages, -> { where(parent_message_id: nil) }

  validates :body, presence: true, length: { maximum: 1000 }

  validate :participants_must_be_different
  validate :exactly_one_student_participant_for_now
  validate :non_student_participant_must_be_teacher_or_admin
  validate :participants_must_match_classroom_context
  validate :root_message_sender_must_not_be_student
  validate :reply_must_target_teacher_or_admin_root_message

  private

  def participants_must_be_different
    return if sender_id.blank? || recipient_id.blank?
    return unless sender_id == recipient_id

    errors.add(:recipient, "은 발신자와 같을 수 없습니다.")
  end

  def exactly_one_student_participant_for_now
    return if sender.blank? || recipient.blank?

    student_count = [sender, recipient].count(&:student?)
    return if student_count == 1

    errors.add(:base, "현재는 teacher/admin 과 student 사이 메시지만 보낼 수 있습니다.")
  end

  def non_student_participant_must_be_teacher_or_admin
    return if sender.blank? || recipient.blank?

    [sender, recipient].each do |participant|
      next if participant.student? || participant.teacher? || participant.admin?

      errors.add(:base, "허용되지 않은 발신자/수신자입니다.")
    end
  end

  def participants_must_match_classroom_context
    return if classroom.blank? || sender.blank? || recipient.blank?

    validate_participant_membership!(sender)
    validate_participant_membership!(recipient)
  end

  def validate_participant_membership!(participant)
    return if participant.admin?
    return if classroom.classroom_memberships.exists?(user_id: participant.id, role: "teacher") && participant.teacher?
    return if classroom.classroom_memberships.exists?(user_id: participant.id, role: "student") && participant.student?

    errors.add(:base, "교실 맥락과 맞지 않는 참여자입니다.")
  end

  def root_message_sender_must_not_be_student
    return if parent_message_id.present?
    return if sender.blank?
    return unless sender.student?

    errors.add(:base, "학생은 새 원글 메시지를 시작할 수 없습니다.")
  end

  def reply_must_target_teacher_or_admin_root_message
    return if parent_message.blank?

    errors.add(:base, "답글의 답글은 이번 단계에서 허용하지 않습니다.") if parent_message.parent_message_id.present?
    errors.add(:base, "학생만 답글을 작성할 수 있습니다.") unless sender&.student?
    errors.add(:base, "teacher/admin 원글에만 답글을 달 수 있습니다.") unless parent_message.sender&.teacher? || parent_message.sender&.admin?
    errors.add(:base, "본인에게 온 원글에만 답글을 달 수 있습니다.") unless parent_message.recipient_id == sender_id
    errors.add(:base, "원글 작성자에게만 답글을 보낼 수 있습니다.") unless recipient_id == parent_message.sender_id
    errors.add(:base, "원글과 같은 교실 맥락에서만 답글을 달 수 있습니다.") unless classroom_id == parent_message.classroom_id
  end
end
