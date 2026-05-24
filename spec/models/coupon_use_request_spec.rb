require "rails_helper"

RSpec.describe CouponUseRequest, type: :model do
  let(:coupon) { create(:user_coupon, :with_classroom_membership) }

  it "creates a pending request for an issued coupon" do
    request = described_class.create!(
      user_coupon: coupon,
      classroom: coupon.classroom,
      student: coupon.user,
      requested_by: coupon.user
    )

    expect(request).to be_pending
    expect(request.requested_at).to be_present
  end

  it "rejects duplicate pending requests for the same coupon" do
    create(:coupon_use_request, user_coupon: coupon, classroom: coupon.classroom, student: coupon.user, requested_by: coupon.user)

    duplicate = described_class.new(
      user_coupon: coupon,
      classroom: coupon.classroom,
      student: coupon.user,
      requested_by: coupon.user
    )

    expect(duplicate).not_to be_valid
  end

  it "rejects requests for used coupons" do
    coupon.update!(status: :used, used_at: Time.zone.local(2026, 4, 7, 11, 0, 0))

    request = described_class.new(
      user_coupon: coupon,
      classroom: coupon.classroom,
      student: coupon.user,
      requested_by: coupon.user
    )

    expect(request).not_to be_valid
  end
end
