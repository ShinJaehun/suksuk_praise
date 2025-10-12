class UserCouponPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      # 교사/관리자는 전체 조회 허용(컨트롤러에서 user_id로 다시 좁혀 사용)
      return scope.all if user.admin? || user.teacher?

      # 학생: 본인 것만
      scope.where(user_id: user.id)
    end
  end

  # index는 policy_scope로 제어되므로 별도 제한 X (원하면 더 엄격히 가능)
  def index?
    user.present?
  end

  # 쿠폰 사용: 본인 or 해당 교실의 교사 or 관리자
  def use?
    return false unless user
    user.admin? || record.user_id == user.id || teacher_of?(record.classroom)
  end

  private

  def teacher_of?(classroom)
    ClassroomMembership.exists?(
      classroom_id: classroom.id,
      user_id: user.id,
      role: "teacher"
    )
  end
end