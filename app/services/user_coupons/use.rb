module UserCoupons
  class Use
    def self.call!(coupon:, actor:, used_at: Time.zone.now)
      ApplicationRecord.transaction do
        coupon.use!(used_at: used_at)

        CouponEvent.create!(
          action: "used",
          actor: actor,
          user_coupon: coupon,
          classroom: coupon.classroom,
          coupon_template: coupon.coupon_template,
          metadata: {
            target_user_id: coupon.user_id,
            target_user_name: coupon.user.name
          }
        )
      end
    end
  end
end