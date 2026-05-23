require "rails_helper"

RSpec.describe CouponTemplatePolicy do
  describe "#update?, #toggle_active?, #destroy?" do
    it "permits a teacher to manage their personal template" do
      teacher = create(:user, :teacher)
      template = create(:coupon_template, created_by: teacher, bucket: "personal")
      policy = described_class.new(teacher, template)

      expect(policy.update?).to eq(true)
      expect(policy.toggle_active?).to eq(true)
      expect(policy.destroy?).to eq(true)
    end

    it "rejects a teacher from directly managing an admin library template" do
      admin = create(:user, :admin)
      teacher = create(:user, :teacher)
      template = create(:coupon_template, created_by: admin, bucket: "library")
      policy = described_class.new(teacher, template)

      expect(policy.update?).to eq(false)
      expect(policy.toggle_active?).to eq(false)
      expect(policy.destroy?).to eq(false)
      expect(policy.adopt?).to eq(true)
    end

    it "permits an admin to manage a library template" do
      admin = create(:user, :admin)
      template = create(:coupon_template, created_by: admin, bucket: "library")
      policy = described_class.new(admin, template)

      expect(policy.update?).to eq(true)
      expect(policy.toggle_active?).to eq(true)
      expect(policy.destroy?).to eq(true)
    end
  end

  describe "Scope.library_scope" do
    it "returns only active admin library templates for a teacher" do
      admin = create(:user, :admin)
      teacher = create(:user, :teacher)
      active_library = create(:coupon_template, created_by: admin, bucket: "library", active: true)
      inactive_library = create(:coupon_template, created_by: admin, bucket: "library", active: false, weight: 0)
      create(:coupon_template, created_by: teacher, bucket: "personal", active: true)

      resolved = described_class::Scope.library_scope(teacher, CouponTemplate)

      expect(resolved.pluck(:id)).to contain_exactly(active_library.id)
      expect(resolved.pluck(:id)).not_to include(inactive_library.id)
    end

    it "returns inactive admin library templates for an admin" do
      admin = create(:user, :admin)
      active_library = create(:coupon_template, created_by: admin, bucket: "library", active: true)
      inactive_library = create(:coupon_template, created_by: admin, bucket: "library", active: false, weight: 0)
      teacher = create(:user, :teacher)
      create(:coupon_template, created_by: teacher, bucket: "personal", active: true)

      resolved = described_class::Scope.library_scope(admin, CouponTemplate)

      expect(resolved.pluck(:id)).to contain_exactly(active_library.id, inactive_library.id)
    end
  end
end
