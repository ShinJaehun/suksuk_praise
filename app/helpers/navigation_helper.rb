module NavigationHelper

  def can_view_coupon_events?
    return false unless current_user
    Pundit.policy!(current_user, CouponEvent).index?
  rescue Pundit::NotDefinedError
    false
  end

  def can_manage_coupon_templates?
    return false unless current_user
    Pundit.policy!(current_user, CouponTemplate).index?
  rescue Pundit::NotDefinedError
    false  
  end

  # 관리자만 교사 관리 화면 접근 가능
  def can_manage_teachers?
    return false unless current_user
    Pundit.policy!(current_user, User).index?
  rescue Pundit::NotDefinedError
    false
  end
end