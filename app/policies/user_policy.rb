class UserPolicy < ApplicationPolicy
  def show?
    return true if user&.admin?

    if user&.teacher?
      # 담임인 반 학생들 정보만 조회 가능
      teacher_classroom_ids = user.classroom_memberships.where(role: 'teacher').pluck(:classroom_id)
      return ClassroomMembership.exists?(user_id: record.id, classroom_id: teacher_classroom_ids)
    end
    # 학생은 본인만
    user&.student? && user.id == record.id
  end
end