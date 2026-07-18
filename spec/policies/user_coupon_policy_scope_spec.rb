require "rails_helper"

RSpec.describe UserCouponPolicy::Scope do
  describe "#resolve" do
    let(:first_classroom) { create(:classroom) }
    let(:second_classroom) { create(:classroom) }
    let(:first_student) { create(:user, :student) }
    let(:second_student) { create(:user, :student) }
    let!(:first_membership) do
      create(:classroom_membership, user: first_student, classroom: first_classroom, role: "student")
    end
    let!(:second_membership) do
      create(:classroom_membership, user: second_student, classroom: second_classroom, role: "student")
    end
    let!(:first_coupon) { create(:user_coupon, user: first_student, classroom: first_classroom) }
    let!(:second_coupon) { create(:user_coupon, user: second_student, classroom: second_classroom) }

    it "returns all coupons for an admin" do
      resolved = described_class.new(create(:user, :admin), UserCoupon.all).resolve

      expect(resolved).to contain_exactly(first_coupon, second_coupon)
    end

    it "returns only coupons from a teacher's assigned classroom" do
      teacher = create(:user, :teacher)
      create(:classroom_membership, user: teacher, classroom: first_classroom, role: "teacher")

      resolved = described_class.new(teacher, UserCoupon.all).resolve

      expect(resolved).to contain_exactly(first_coupon)
    end

    it "returns coupons from every classroom assigned to a teacher" do
      teacher = create(:user, :teacher)
      create(:classroom_membership, user: teacher, classroom: first_classroom, role: "teacher")
      create(:classroom_membership, user: teacher, classroom: second_classroom, role: "teacher")

      resolved = described_class.new(teacher, UserCoupon.all).resolve

      expect(resolved).to contain_exactly(first_coupon, second_coupon)
    end

    it "does not expand coupon access for an unassigned school manager" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: first_classroom.school, user: manager)

      resolved = described_class.new(manager, UserCoupon.all).resolve

      expect(resolved).to be_empty
    end

    it "returns only the student's own coupons" do
      resolved = described_class.new(first_student, UserCoupon.all).resolve

      expect(resolved).to contain_exactly(first_coupon)
    end

    it "returns no coupons for a guest" do
      resolved = described_class.new(nil, UserCoupon.all).resolve

      expect(resolved).to be_empty
    end
  end
end
