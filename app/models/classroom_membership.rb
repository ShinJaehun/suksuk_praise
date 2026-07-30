class ClassroomMembership < ApplicationRecord
  belongs_to :user
  belongs_to :classroom

  enum role: { student: "student", teacher: "teacher" }
  enum :status, { active: "active", inactive: "inactive" }

  scope :in_roster_order, -> {
    joins(:user).order(
      Arel.sql("classroom_memberships.student_number ASC NULLS LAST"),
      Arel.sql("users.name ASC"),
      Arel.sql("classroom_memberships.user_id ASC"),
      Arel.sql("classroom_memberships.id ASC")
    )
  }

  validates :student_number,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 },
    allow_nil: true
  validates :student_number,
    uniqueness: {
      scope: :classroom_id,
      conditions: -> { student.active.where.not(student_number: nil) }
    },
    if: :numbered_active_student_membership?
  validate :one_active_classroom_per_student, if: :active_student_membership?
  validate :teacher_membership_must_be_active

  private

  def numbered_active_student_membership?
    student? && active? && student_number.present?
  end

  def active_student_membership?
    student? && active?
  end

  def one_active_classroom_per_student
    return if user_id.blank?

    existing_memberships = self.class.student.active.where(user_id: user_id)
    existing_memberships = existing_memberships.where.not(id: id) if persisted?
    return unless existing_memberships.exists?

    errors.add(:base, :active_student_membership_taken)
  end

  def teacher_membership_must_be_active
    return unless teacher? && inactive?

    errors.add(:status, :teacher_must_be_active)
  end
end
