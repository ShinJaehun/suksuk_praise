class ClassroomStudentPolicy < ApplicationPolicy
  def create?
    return true if admin?
    teacher_of?(record.classroom)
  end

  def destroy?
    create?
  end

  private
  
  def teacher_of?(classroom)
    return false unless teacher?
    classroom.classroom_memberships.exists?(user_id: user.id, role: "teacher")
  end
end