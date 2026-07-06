require "rails_helper"

RSpec.describe UserCoupons::Issue, type: :service do
  it "creates an issued coupon and its event atomically" do
    classroom = create(:classroom)
    teacher = create(:user, :teacher)
    student = create(:user, :student)
    template = create(:coupon_template, created_by: teacher, active: true)
    create(:classroom_membership, classroom: classroom, user: student, role: "student")

    expect {
      described_class.call!(
        user: student,
        classroom: classroom,
        template: template,
        issued_by: teacher,
        issuance_basis: "manual",
        period_start_on: Time.zone.today,
        basis_tag: "selected"
      )
    }.to change(UserCoupon, :count).by(1)
      .and change(CouponEvent, :count).by(1)

    coupon = UserCoupon.last
    expect(coupon).to have_attributes(
      user: student,
      classroom: classroom,
      coupon_template: template,
      issued_by: teacher,
      status: "issued",
      issuance_basis: "manual",
      basis_tag: "selected"
    )
    expect(CouponEvent.last).to have_attributes(
      action: "issued",
      actor: teacher,
      user_coupon: coupon,
      classroom: classroom,
      coupon_template: template
    )
  end
end
