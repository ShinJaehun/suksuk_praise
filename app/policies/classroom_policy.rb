class ClassroomPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      return scope.all if user.admin?
      scope.joins(:classroom_memberships)
        .where(classroom_memberships: { user_id: user.id })
        .distinct
    end
  end
  
  def show?
    user.admin? || record.classroom_memberships.exists?(user_id: user.id)
  end

  def create?
    user.admin? || user.teacher?
  end
  
  def new?
    create?
  end

  def update?
    user.admin? || record.classroom_memberships.exists?(user_id: user.id, role: "teacher")
  end

  def edit?
    update?
  end

  def destroy?
    update?
  end

end