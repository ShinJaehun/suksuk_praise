module UserCoupons
  class Issue
    def self.call!(user:, classroom:, template:, issued_by:, issuance_basis:, period_start_on:, basis_tag:)
      ApplicationRecord.transaction do
        issued = UserCoupon.issue!(
          user: user,
          classroom: classroom,
          template: template,
          issued_by: issued_by,
          issuance_basis: issuance_basis,
          period_start_on: period_start_on,
          basis_tag: basis_tag
        )

        CouponEvent.create!(
          action: "issued",
          actor: issued_by,
          user_coupon: issued,
          classroom: classroom,
          coupon_template: template,
          metadata: {
            basis: issued.issuance_basis,
            mode: issued.basis_tag,
            target_user_id: issued.user_id,
            target_user_name: user.name
          }
        )

        issued
      end
    end
  end
end
