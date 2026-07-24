class ComplimentPresetPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.teacher? || user&.admin?

      scope.where(user_id: user.id)
    end
  end

  def index?
    admin? || teacher?
  end

  def create?
    index?
  end

  def update?
    owner?
  end

  def edit?
    update?
  end

  def destroy?
    owner?
  end

  private

  def owner?
    return false unless user && record.respond_to?(:user_id)

    record.user_id == user.id && (admin? || teacher?)
  end
end
