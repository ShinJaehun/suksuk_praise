class ClassroomStudentPolicy < ApplicationPolicy
  def create?
    user.admin? || record.classroom.classroom_memberships.exists?(user_id: user.id, role: "teacher")
  end
end