# app/policies/coupon_template_policy.rb
class CouponTemplatePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # 교사용 index: "내 쿠폰" = 내가 만든 persoanl만
    def resolve
      return scope.none unless user
      scope.personal_for(user)
    end

    # 교사: admin 소유 + bucket=library + active=true 만 읽기 전용
    # 관리자: admin 소유 + bucket=library (active 여부 무관) 조회/수정 가능
    def self.library_scope(user, scope)
      base = scope.joins(:created_by)
                  .merge(User.where(role: "admin"))
                  .where(bucket: "library")
      base = base.where(active: true) unless user&.admin?
      base
        .select(:id, :title, :weight, :active, :created_by_id, :bucket)
        .order(:title)
    end
  end

  def index?
    user.admin? || user.teacher?
  end

  def library?
    user.admin? || user.teacher?
  end

  def create?
    user.admin? || user.teacher?
  end

  def update?
    user.admin? || owner?
  end

  def toggle_active?
    user.admin? || owner?
  end

  def destroy?
    user.admin? || owner?
  end

  def adopt?
    user.admin? || user.teacher?
  end

  def bump_weight?
    user.admin? || owner?
  end

  def rebalance_equal?
    user.admin? || user.teacher?
  end

  private
  def owner? 
    record.created_by_id == user.id
  end
end