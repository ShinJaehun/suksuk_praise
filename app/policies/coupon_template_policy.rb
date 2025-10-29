# app/policies/coupon_template_policy.rb
class CouponTemplatePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # 교사용 index: "내 쿠폰" = 내가 만든 것만
    def resolve
      scope.personal_for(user)
    end

    # 교사 라이브러리: 관리자 소유 + library + active
    def library_for_teacher
      scope.joins(:created_by)
           .merge(User.where(role: "admin"))
           .where(bucket: "library", active: true)
    end

    # 관리자 라이브러리: 본인 소유 + library
    def library_for_admin
      scope.where(created_by_id: user.id, bucket: "library")
    end
  end

  def index?
    user.admin? || user.teacher?
  end

  def library?
    user.admin? || user.teacher? # 읽기 전용
  end

  def create?
    user.admin? || user.teacher?
  end

  def update?
    user.admin? || owner?
  end

  def adopt?
    user.admin? || user.teacher?
  end

  def toggle_active?
    user.admin? || owner?
  end

  def destroy?
    user.admin? || owner?
  end

  # 라이브러리(교사 노출/채택 대상):
  # 관리자(=admin) 소유 + bucket=library + active
  def self.library_scope(user, scope)
    scope.joins(:created_by)
         .merge(User.where(role: "admin"))
         .where(bucket: "library", active: true)
  end

  private
  def owner? 
    record.created_by_id == user.id
  end
end