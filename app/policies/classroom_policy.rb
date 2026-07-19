class ClassroomPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?

      if user&.teacher? && user.school_membership&.manager?
        return scope.where(school_id: user.school_membership.school_id)
      end

      # Teachers can see only their classrooms
      if user&.teacher?
        return scope.joins(:classroom_memberships)
                    .where(classroom_memberships: { user_id: user.id, role: 'teacher' })
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

    school_manager_of?(record) || member_of?(record)
  end

  def create?
    admin? || school_manager?
  end

  def new?
    create?
  end

  def update?
    manage_structure? || manage_operations?
  end

  def edit?
    update?
  end

  def destroy?
    !!admin?
  end

  def manage_members?
    admin? || teacher_of?(record)
  end

  def manage_structure?
    !!(admin? || school_manager_of?(record))
  end

  def manage_operations?
    !!(admin? || teacher_of?(record))
  end

  def view_student_data?
    return true if admin?
    return teacher_of?(record) if teacher?
    return student_of?(record) if student?

    false
  end

  def create_compliment?
    admin? || teacher_of?(record)
  end

  def refresh_compliment_king?
    admin? || teacher_of?(record)
  end

  def draw_coupon?
    admin? || teacher_of?(record)
  end

  private

  def school_manager?
    teacher? && user.school_membership&.manager?
  end

  def school_manager_of?(classroom)
    school_manager? && classroom.school_id == user.school_membership.school_id
  end

  def teacher_of?(classroom)
    return false unless user&.teacher?

    classroom.classroom_memberships.exists?(user_id: user.id, role: 'teacher')
  end

  def member_of?(classroom)
    return false unless user

    classroom.classroom_memberships.exists?(user_id: user.id)
  end

  def student_of?(classroom)
    return false unless user&.student?

    classroom.classroom_memberships.exists?(user_id: user.id, role: 'student')
  end
end
