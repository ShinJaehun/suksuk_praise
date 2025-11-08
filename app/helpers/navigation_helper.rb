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
    false  end
end