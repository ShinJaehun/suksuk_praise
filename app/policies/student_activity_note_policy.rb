class StudentActivityNotePolicy < ApplicationPolicy
  def create?
    admin? || current_classroom_teacher?
  end

  def update?
    admin? || (current_classroom_teacher? && record.author_id == user.id)
  end

  def destroy?
    update?
  end

  private

  def current_classroom_teacher?
    return false unless teacher?

    classroom_id = record.classroom_id || record.source&.classroom_id
    classroom_id && user.classroom_memberships.exists?(classroom_id: classroom_id, role: "teacher")
  end
end
