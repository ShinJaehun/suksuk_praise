require "rails_helper"

RSpec.describe ClassroomPolicy do
  describe "#draw_coupon?" do
    let(:classroom) { create(:classroom) }

    it "permits admin" do
      admin = create(:user, :admin)

      expect(described_class.new(admin, classroom).draw_coupon?).to eq(true)
    end

    it "permits a teacher member of the classroom" do
      teacher = create(:user, :teacher)
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")

      expect(described_class.new(teacher, classroom).draw_coupon?).to eq(true)
    end

    it "rejects a non-member teacher" do
      teacher = create(:user, :teacher)

      expect(described_class.new(teacher, classroom).draw_coupon?).to eq(false)
    end

    it "rejects a student member" do
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: "student")

      expect(described_class.new(student, classroom).draw_coupon?).to eq(false)
    end
  end
end
