class UserCouponPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      return scope.all if user.admin?

      if user.teacher?
        teacher_classroom_ids = ClassroomMembership
          .where(user_id: user.id, role: "teacher")
          .select(:classroom_id)
        return scope.where(classroom_id: teacher_classroom_ids)
      end

      # 학생: 본인 것만
      return scope.where(user_id: user.id) if user.student?

      scope.none
    end
  end

  # index는 policy_scope로 제어되므로 별도 제한 X (원하면 더 엄격히 가능)
  def index?
    user.present?
  end

  # 쿠폰 사용: 해당 교실의 교사 or 관리자
  def use?
    return false unless user

    user.admin? || teacher_of?(record.classroom)
  end

  private

  def teacher_of?(classroom)
    ClassroomMembership.exists?(
      classroom_id: classroom.id,
      user_id: user.id,
      role: 'teacher'
    )
  end
end
