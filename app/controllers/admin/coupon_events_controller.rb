class Admin::CouponEventsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize CouponEvent
    @events = policy_scope(CouponEvent)
      .includes(:actor, :classroom, :coupon_template, :user_coupon)
      .order(created_at: :desc)
      .limit(50)
  end
end
