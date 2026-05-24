class CouponUseRequestPolicy < ApplicationPolicy
  def create?
    return false unless user&.student?
    return false unless record.student_id == user.id
    return false unless record.requested_by_id == user.id

    record.user_coupon&.issued?
  end

  def approve?
    return false unless user
    return true if user.admin?

    user.teacher? && ClassroomMembership.exists?(
      classroom_id: record.classroom_id,
      user_id: user.id,
      role: "teacher"
    )
  end
end
