class SchoolPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?
      return scope.active.where(id: user.school_membership.school_id) if user&.active_teacher? && user.school_membership

      scope.none
    end
  end

  def index?
    admin? || (teacher? && user.school_membership.present?)
  end

  def show?
    admin? || (record.active? && school_member?)
  end

  def manage_operations?
    record.active? && (admin? || school_manager?)
  end

  def manage_teachers?
    record.active? && school_manager?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def deactivate?
    admin? && record.active?
  end

  def reactivate?
    admin? && record.inactive?
  end

  def destroy?
    false
  end

  private

  def school_member?
    teacher? && user.school_membership&.school_id == record.id
  end

  def school_manager?
    school_member? && user.school_membership.manager?
  end
end
