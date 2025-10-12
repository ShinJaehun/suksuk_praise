class CouponEventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user
      return scope.all if user.admin?

      if user.teacher?
        teacher_classroom_ids = user.classroom_memberships
          .where(role: 'teacher')
          .pluck(:classroom_id)

        return scope.where(classroom_id: teacher_classroom_ids)
          .or(scope.where(actor_id: user.id))
          .distinct
      end

      scope.none
    end
  end

  def index?
    user.present? && (admin? || teacher?)
  end

end
