module UserShowDataLoader
  extend ActiveSupport::Concern

  private

  def load_user_show_data!(user:, classroom:, include_recent_issued:, recent_in_classroom:)
    compliments_scope = policy_scope(Compliment).where(receiver_id: user.id)
    compliments_scope = compliments_scope.where(classroom_id: classroom.id) if classroom
    @compliments = compliments_scope.includes(:giver, :classroom).order(given_at: :desc)

    coupons_scope = policy_scope(UserCoupon).where(user_id: user.id)
    coupons_scope = coupons_scope.where(classroom_id: classroom.id) if classroom
    @coupons = coupons_scope
      .where(status: "issued")
      .includes(:coupon_template)
      .order(issued_at: :desc)

    @kpi_counts = {
      points: user.points,
      today_compliments: compliments_scope.where(given_at: Time.zone.today.all_day).count,
      issued_count: @coupons.size,
      today_issued_coupons: coupons_scope.where(issued_at: Time.zone.today.all_day).count,
      used_coupons: coupons_scope.where(status: "used").count
    }

    return unless include_recent_issued

    recent_scope = policy_scope(UserCoupon).where(user_id: user.id)
    recent_scope = recent_scope.where(classroom_id: classroom.id) if classroom && recent_in_classroom
    @recent_issued_coupons = recent_scope
      .includes(:coupon_template, :user)
      .order(issued_at: :desc)
      .limit(10)
  end
end
