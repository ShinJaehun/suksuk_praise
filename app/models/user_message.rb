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
  scope :unread, -> { where(read_at: nil) }
  scope :sent_by_students, -> { joins(:sender).where(users: { role: "student" }) }
  scope :unread_student_messages, -> { unread.sent_by_students }

  before_validation :mark_non_student_sender_messages_read, on: :create

  validates :body, presence: true, length: { maximum: 1000 }

  validate :participants_must_be_different
  validate :classroom_message_policy_allows_message
  validate :exactly_one_student_participant_for_now
  validate :non_student_participant_must_be_teacher_or_admin
  validate :participants_must_match_classroom_context
  validate :student_root_message_must_target_classroom_teacher
  validate :reply_must_target_root_message

  private

  def mark_non_student_sender_messages_read
    return if read_at.present?
    return if sender.blank? || sender.student?

    self.read_at = Time.current
  end

  def participants_must_be_different
    return if sender_id.blank? || recipient_id.blank?
    return unless sender_id == recipient_id

    errors.add(:recipient, "은 발신자와 같을 수 없습니다.")
  end

  def classroom_message_policy_allows_message
    return if classroom.blank?
    return if classroom.student_messages_enabled?

    errors.add(:base, "메시지 기능을 사용하지 않는 교실입니다.")
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

  def student_root_message_must_target_classroom_teacher
    return if parent_message_id.present?
    return if sender.blank? || recipient.blank?
    return unless sender.student?

    unless classroom&.student_can_start_messages?
      errors.add(:base, "학생 새 메시지가 허용되지 않은 교실입니다.")
      return
    end

    return if recipient.teacher? && classroom.classroom_memberships.exists?(user_id: recipient.id, role: "teacher")

    errors.add(:base, "학생은 자기 교실 선생님에게만 새 메시지를 보낼 수 있습니다.")
  end

  def reply_must_target_root_message
    return if parent_message.blank?

    errors.add(:base, "답글의 답글은 이번 단계에서 허용하지 않습니다.") if parent_message.parent_message_id.present?
    errors.add(:base, "원글과 같은 교실 맥락에서만 답글을 달 수 있습니다.") unless classroom_id == parent_message.classroom_id

    if sender&.student?
      errors.add(:base, "본인이 참여한 원글에만 답글을 달 수 있습니다.") unless [parent_message.sender_id, parent_message.recipient_id].include?(sender_id)
      errors.add(:base, "원글의 상대 참여자에게만 답글을 보낼 수 있습니다.") unless recipient_id == other_root_participant_id(sender_id)
    elsif sender&.teacher? || sender&.admin?
      errors.add(:base, "학생이 참여한 원글에만 답글을 달 수 있습니다.") unless [parent_message.sender, parent_message.recipient].any?(&:student?)
      errors.add(:base, "원글의 학생 참여자에게만 답글을 보낼 수 있습니다.") unless recipient_id == root_student_participant_id
    else
      errors.add(:base, "허용되지 않은 답글 작성자입니다.")
    end
  end

  def root_student_participant_id
    return parent_message.sender_id if parent_message.sender&.student?
    return parent_message.recipient_id if parent_message.recipient&.student?

    nil
  end

  def other_root_participant_id(participant_id)
    return parent_message.recipient_id if parent_message.sender_id == participant_id
    return parent_message.sender_id if parent_message.recipient_id == participant_id

    nil
  end
end
