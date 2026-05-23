require "rails_helper"

RSpec.describe UserCoupons::Use, type: :service do
  describe ".call!" do
    it "marks the coupon as used and records a used event with target metadata" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher)
      used_at = Time.zone.local(2026, 4, 7, 11, 0, 0)
      coupon = create(
        :user_coupon,
        :with_classroom_membership,
        user: student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher
      )

      expect {
        described_class.call!(coupon: coupon, actor: teacher, used_at: used_at)
      }.to change(CouponEvent, :count).by(1)

      event = CouponEvent.order(:id).last

      expect(coupon.reload).to be_used
      expect(coupon.used_at).to eq(used_at)
      expect(event).to have_attributes(
        action: "used",
        actor: teacher,
        user_coupon: coupon,
        classroom: classroom,
        coupon_template: template
      )
      expect(event.metadata["target_user_id"]).to eq(student.id)
      expect(event.metadata["target_user_name"]).to eq(student.name)
    end

    it "does not create an event when the coupon was already used" do
      teacher = create(:user, :teacher)
      coupon = create(
        :user_coupon,
        :with_classroom_membership,
        status: :used,
        used_at: Time.zone.local(2026, 4, 7, 11, 0, 0)
      )

      expect {
        described_class.call!(coupon: coupon, actor: teacher)
      }.to raise_error(ActiveRecord::RecordInvalid)
      expect(CouponEvent.count).to eq(0)
    end
  end
end
