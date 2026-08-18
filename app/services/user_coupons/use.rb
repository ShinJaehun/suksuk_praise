module UserCoupons
  class Use
    class InactiveStudentError < StandardError; end

    def self.call!(coupon:, actor:, used_at: Time.zone.now)
      ApplicationRecord.transaction do
        membership = ClassroomMembership.lock.find_by(
          user_id: coupon.user_id,
          classroom_id: coupon.classroom_id,
          role: "student"
        )
        raise InactiveStudentError unless membership&.active?

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
