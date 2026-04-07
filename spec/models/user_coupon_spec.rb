require "rails_helper"

RSpec.describe UserCoupon, type: :model do
  describe ".period_start_for" do
    it "returns the same day for daily issuance" do
      now = Time.zone.local(2026, 4, 7, 10, 30, 0)

      expect(described_class.period_start_for("daily", now: now)).to eq(Date.new(2026, 4, 7))
    end

    it "returns the monday of the week for weekly issuance" do
      now = Time.zone.local(2026, 4, 7, 10, 30, 0)

      expect(described_class.period_start_for("weekly", now: now)).to eq(Date.new(2026, 4, 6))
    end

    it "uses the same day for manual issuance" do
      now = Time.zone.local(2026, 4, 7, 10, 30, 0)

      expect(described_class.period_start_for("manual", now: now)).to eq(Date.new(2026, 4, 7))
    end
  end

  describe ".issue!" do
    it "creates an issued coupon with issuance context" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher)
      issued_at = Time.zone.local(2026, 4, 7, 10, 30, 0)
      create(:classroom_membership, user: student, classroom: classroom, role: "student")

      coupon = described_class.issue!(
        user: student,
        classroom: classroom,
        template: template,
        issued_by: teacher,
        issued_at: issued_at,
        issuance_basis: "daily",
        basis_tag: "daily_top"
      )

      expect(coupon).to be_issued
      expect(coupon.issued_by).to eq(teacher)
      expect(coupon.period_start_on).to eq(Date.new(2026, 4, 7))
      expect(coupon.basis_tag).to eq("daily_top")
    end

    it "rejects a student who does not belong to the classroom" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher)

      expect {
        described_class.issue!(
          user: student,
          classroom: classroom,
          template: template,
          issued_by: teacher
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#use!" do
    it "marks an issued coupon as used" do
      coupon = create(:user_coupon)
      used_at = Time.zone.local(2026, 4, 7, 11, 0, 0)

      coupon.use!(used_at: used_at)

      expect(coupon).to be_used
      expect(coupon.used_at).to eq(used_at)
    end

    it "rejects repeated use" do
      coupon = create(:user_coupon, status: :used, used_at: Time.zone.local(2026, 4, 7, 11, 0, 0))

      expect {
        coupon.use!
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
