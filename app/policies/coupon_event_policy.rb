class CouponEventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user
      return scope.all  if user.admin?

      if user.teacher?
        teacher_classroom_ids = user.classroom_memberships
                                    .where(role: "teacher")
                                    .pluck(:classroom_id)

        scope.where(classroom_id: teacher_classroom_ids)
             .or(scope.where(actor_id: user.id)) # 본인이 행한 이벤트는 항상 볼 수 있게
             .distinct
      else
        scope.none
      end
    end
  end

  # /admin/coupon_events#index 에서 authorize CouponEvent 호출 시 사용됨
  def index?
    user&.admin? || user&.teacher?
  end

end
