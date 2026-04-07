require "rails_helper"

RSpec.describe CouponTemplates::WeightBalancer, type: :service do
  describe ".normalize!" do
    it "sets inactive personal template weights to zero" do
      teacher = create(:user, :teacher)
      inactive = create(:coupon_template, created_by: teacher, active: false, weight: 30)
      active = create(:coupon_template, created_by: teacher, active: true, weight: 70)

      described_class.normalize!(teacher)

      expect(inactive.reload.weight).to eq(0)
      expect(active.reload.weight).to eq(100)
    end

    it "assigns all weight to a single active personal template" do
      teacher = create(:user, :teacher)
      template = create(:coupon_template, created_by: teacher, active: true, weight: 10)

      described_class.normalize!(teacher)

      expect(template.reload.weight).to eq(100)
    end

    it "splits weight equally when active templates include zero weight" do
      teacher = create(:user, :teacher)
      first = create(:coupon_template, created_by: teacher, active: true, weight: 0)
      second = create(:coupon_template, created_by: teacher, active: true, weight: 0)
      third = create(:coupon_template, created_by: teacher, active: true, weight: 0)

      described_class.normalize!(teacher)

      expect([first.reload.weight, second.reload.weight, third.reload.weight]).to eq([40, 30, 30])
    end

    it "preserves proportions using ten-point units" do
      teacher = create(:user, :teacher)
      first = create(:coupon_template, created_by: teacher, active: true, weight: 20)
      second = create(:coupon_template, created_by: teacher, active: true, weight: 80)

      described_class.normalize!(teacher)

      expect([first.reload.weight, second.reload.weight]).to eq([20, 80])
    end

    it "does not change another teacher's personal templates" do
      teacher = create(:user, :teacher)
      other_teacher = create(:user, :teacher)
      create(:coupon_template, created_by: teacher, active: true, weight: 10)
      other_template = create(:coupon_template, created_by: other_teacher, active: true, weight: 25)

      described_class.normalize!(teacher)

      expect(other_template.reload.weight).to eq(25)
    end
  end

  describe ".normalize_library!" do
    it "turns off active library templates with non-positive weight" do
      admin = create(:user, :admin)
      bad = create(:coupon_template, created_by: admin, bucket: "library", active: true, weight: 0)
      good = create(:coupon_template, created_by: admin, bucket: "library", active: true, weight: 100)

      described_class.normalize_library!

      expect(bad.reload).not_to be_active
      expect(bad.weight).to eq(0)
      expect(good.reload.weight).to eq(100)
    end
  end
end
