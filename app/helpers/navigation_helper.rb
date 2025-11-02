module NavigationHelper
  # Navbar 노출 권한: 뷰에서 policy 호출을 숨기기 위해 헬퍼로 캡슐화
  def can_view_coupon_events?
    return false unless current_user
    Pundit.policy!(current_user, CouponEvent).index?
  rescue Pundit::NotDefinedError
    false
  end
end