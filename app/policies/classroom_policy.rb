class ClassroomPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?

      # Teachers can see only their classrooms
      if user&.teacher?
        return scope.joins(:classroom_memberships)
          .where(classroom_memberships: { user_id: user.id, role: "teacher" })
          .distinct
      end

      # Students can see only their classrooms
      if user&.student?
        return scope.joins(:classroom_memberships)
          .where(classroom_memberships: { user_id: user.id })
          .distinct
      end

      scope.none
    end
  end

  def index?
    admin? || teacher? || student?
  end
  
  def show?
    return true if admin?
    member_of?(record)
  end

  def create?
    admin? || teacher?
  end
  
  def new?
    create?
  end

  def update?
    return true if admin?
    teacher_of?(record)
  end

  def edit?
    update?
  end

  def destroy?
    update?
  end

  def manage_members?
    update?
  end

  def create_compliment?
    update?
  end

  def refresh_compliment_king?
    update?
  end

  def draw_coupon?
    update?
  end

  private

  def teacher_of?(classroom)
    classroom.classroom_memberships.exists?(user_id: user.id, role: "teacher")
  end

  def member_of?(classroom)
    classroom.classroom_memberships.exists?(user_id: user.id)
  end
end