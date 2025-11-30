class UserPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        # 안전한 기본값: 자기 자신만
        scope.where(id: user.id)
      end
    end
  end
  
  def index?
    user.admin?
  end

  def create?
    user.admin?
  end

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

  # Admin 영역에서 교사 계정 수정 권한
  def edit?
    update?
  end

  def update?
    # 관리자이면서, 대상이 교사 계정일 때만 허용
    user&.admin? && record.teacher?
  end
end