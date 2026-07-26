require "rails_helper"

RSpec.describe CouponUseRequestPolicy do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:user, :student) }
  let(:teacher) { create(:user, :teacher) }
  let!(:student_membership) do
    create(
      :classroom_membership,
      user: student,
      classroom: classroom,
      role: "student",
      status: "active"
    )
  end
  let(:coupon) { create(:user_coupon, user: student, classroom: classroom, status: :issued) }
  let(:request) do
    build(
      :coupon_use_request,
      user_coupon: coupon,
      classroom: classroom,
      student: student,
      requested_by: student
    )
  end

  describe "#create?" do
    it "allows the owner with an active student membership and an issued coupon" do
      expect(described_class.new(student, request).create?).to eq(true)
    end

    it "rejects an inactive student membership" do
      student_membership.inactive!

      expect(described_class.new(student, request).create?).to eq(false)
    end

    it "rejects a coupon that is not issued" do
      coupon.update!(status: :used)

      expect(described_class.new(student, request).create?).to eq(false)
    end
  end

  describe "#approve?" do
    it "allows an assigned classroom teacher" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")

      expect(described_class.new(teacher, request).approve?).to eq(true)
    end

  end
end
