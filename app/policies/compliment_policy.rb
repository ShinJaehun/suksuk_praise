class ComplimentPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      return scope.all if user&.admin?
      if user&.teacher? #담임인 반의 칭찬만
        return scope.joins(classroom: :classroom_memberships)
          .where(classroom_memberships: { user_id: user.id, role: "teacher" })
      end #자기네 반만?
      
      scope.joins(classroom: :classroom_memberships)
        .where(classroom_memberships: { user_id: user.id })
      
    end
  end

  # def index?
  #   admin? || teacher? || student?
  # end
  
  def show?
    admin? || member_of?(record.classroom)
  end

  def create?
    return true if admin?
    teacher_of?(record.classroom)
  end

  def update?
    admin? || teacher_of?(record.classroom)
  end

  def destroy?
    update?
  end

  private

  def teacher_of?(classroom)
    return false unless teacher?
    classroom.classroom_memberships.exists?(user_id: user.id, role: "teacher")
  end

  def member_of?(classroom)
    classroom.classroom_memberships.exists?(user_id: user.id)
  end
end