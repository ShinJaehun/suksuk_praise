require "rails_helper"

RSpec.describe UserCouponPolicy::Scope do
  describe "#resolve" do
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let(:other_student) { create(:user, :student) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }
    let!(:other_student_membership) { create(:classroom_membership, user: other_student, classroom: classroom, role: "student") }
    let!(:student_coupon) { create(:user_coupon, :with_classroom_membership, user: student, classroom: classroom) }
    let!(:other_coupon) { create(:user_coupon, :with_classroom_membership, user: other_student, classroom: classroom) }

    it "returns all coupons for admin" do
      admin = create(:user, :admin)

      resolved = described_class.new(admin, UserCoupon.all).resolve

      expect(resolved).to contain_exactly(student_coupon, other_coupon)
    end

    it "returns all coupons for teacher under the current implementation" do
      resolved = described_class.new(teacher, UserCoupon.all).resolve

      expect(resolved).to contain_exactly(student_coupon, other_coupon)
    end

    it "returns only the student's own coupons for student" do
      resolved = described_class.new(student, UserCoupon.all).resolve

      expect(resolved).to contain_exactly(student_coupon)
    end

    it "returns no coupons for guest" do
      resolved = described_class.new(nil, UserCoupon.all).resolve

      expect(resolved).to be_empty
    end
  end
end
