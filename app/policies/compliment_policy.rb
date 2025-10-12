class ComplimentPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # 주체: user(current_user), 대상: scope(Compliment)
    # 컨트롤러에서 receiver_id(@user.id)로 좁힌 뒤 이 scope를 태우면,
    # 현재 사용자 권한에 맞는 교실/대상만 보이게 됩니다.
    
    def resolve
      return scope.all if user&.admin?
      
      if user&.teacher? 
        # 교사가 볼 수 있는 교실에서 발생한 칭찬만
        teacher_classroom_ids = user.classroom_memberships.where(role: 'teacher').pluck(:classroom_id)
        return scope.where(classroom_id: teacher_classroom_ids)
      end
      
      if user&.student?
        # 학생은 자신이 받은 칭찬만
        return scope.where(receiver_id: user.id)
      end

      scope.none
    end
  end

  # def index?
  #   admin? || teacher? || student?
  # end
  
  def show?
    admin? || member_of?(record.classroom)
  end

  def create?
    return true if admin?
    teacher_of?(record.classroom)
  end

  def update?
    admin? || teacher_of?(record.classroom)
  end

  def destroy?
    update?
  end

  private

  def teacher_of?(classroom)
    return false unless teacher?
    classroom.classroom_memberships.exists?(user_id: user.id, role: "teacher")
  end

  def member_of?(classroom)
    classroom.classroom_memberships.exists?(user_id: user.id)
  end
end