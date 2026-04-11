require "rails_helper"

RSpec.describe UserCouponPolicy do
  describe "#use?" do
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }
    let(:coupon) { create(:user_coupon, :with_classroom_membership, user: student, classroom: classroom) }

    it "permits admin" do
      admin = create(:user, :admin)

      expect(described_class.new(admin, coupon).use?).to eq(true)
    end

    it "permits the coupon owner" do
      expect(described_class.new(student, coupon).use?).to eq(true)
    end

    it "permits a teacher member of the coupon classroom" do
      expect(described_class.new(teacher, coupon).use?).to eq(true)
    end

    it "rejects another student" do
      other_student = create(:user, :student)

      expect(described_class.new(other_student, coupon).use?).to eq(false)
    end

    it "rejects a teacher outside the coupon classroom" do
      outsider = create(:user, :teacher)

      expect(described_class.new(outsider, coupon).use?).to eq(false)
    end
  end
end
