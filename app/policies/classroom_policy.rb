class ClassroomPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?

      if user&.active_teacher? && user.school_membership&.manager?
        return scope.joins(:school).merge(School.active)
          .where(school_id: user.school_membership.school_id)
      end

      # Teachers can see only their classrooms
      if user&.active_teacher?
        return scope.joins(:school, :classroom_memberships)
                    .merge(School.active)
                    .where(classroom_memberships: { user_id: user.id, role: 'teacher' })
                    .distinct
      end

      # Students can see only their classrooms
      if user&.student?
        return scope.joins(:school, :classroom_memberships)
                    .merge(School.active)
                    .where(classroom_memberships: { user_id: user.id, role: 'student', status: 'active' })
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
    return false unless active_school?

    school_manager_of?(record) || member_of?(record)
  end

  def create?
    admin? || (school_manager? && user.school_membership.school.active?)
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
    active_school? && !!admin?
  end

  def manage_members?
    active_school? && (admin? || teacher_of?(record))
  end

  def manage_structure?
    active_school? && !!(admin? || school_manager_of?(record))
  end

  def manage_operations?
    active_school? && !!(admin? || teacher_of?(record))
  end

  def view_student_data?
    return false unless active_school?
    return true if admin?
    return teacher_of?(record) if teacher?
    return student_of?(record) if student?

    false
  end

  def create_compliment?
    active_school? && (admin? || teacher_of?(record))
  end

  def refresh_compliment_king?
    active_school? && (admin? || teacher_of?(record))
  end

  def draw_coupon?
    active_school? && (admin? || teacher_of?(record))
  end

  private

  def active_school?
    return true if admin? && record.respond_to?(:new_record?) && record.new_record?

    record.respond_to?(:school) && record.school&.active?
  end

  def school_manager?
    teacher? && user.school_membership&.manager?
  end

  def school_manager_of?(classroom)
    school_manager? && classroom.school_id == user.school_membership.school_id
  end

  def teacher_of?(classroom)
    return false unless user&.active_teacher?

    classroom.classroom_memberships.exists?(user_id: user.id, role: 'teacher')
  end

  def member_of?(classroom)
    return false unless user

    return teacher_of?(classroom) if teacher?
    return student_of?(classroom) if student?

    false
  end

  def student_of?(classroom)
    return false unless user&.student?

    classroom.classroom_memberships.exists?(user_id: user.id, role: 'student', status: 'active')
  end
end
