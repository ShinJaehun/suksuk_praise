class CouponEventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user
      return scope.all  if user.admin?

      if user.active_teacher?
        active_classroom_ids = Classroom
          .joins(:school)
          .merge(School.active)
          .select(:id)
        teacher_classroom_ids = user.classroom_memberships
                                    .joins(classroom: :school)
                                    .merge(School.active)
                                    .where(role: "teacher")
                                    .pluck(:classroom_id)

        scope.where(classroom_id: teacher_classroom_ids)
             .or(scope.where(actor_id: user.id, classroom_id: active_classroom_ids))
             .distinct
      else
        scope.none
      end
    end
  end

  # /admin/coupon_events#index 에서 authorize CouponEvent 호출 시 사용됨
  def index?
    user&.admin? || user&.active_teacher?
  end

end
