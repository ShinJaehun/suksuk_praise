class ClassroomMembership < ApplicationRecord
  belongs_to :user
  belongs_to :classroom

  enum role: { student: "student", teacher: "teacher" }
  enum :status, { active: "active", inactive: "inactive" }

  validate :one_active_classroom_per_student, if: :active_student_membership?

  private

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
end
