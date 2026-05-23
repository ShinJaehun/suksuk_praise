require "rails_helper"

RSpec.describe ClassroomStudentPolicy do
  let(:classroom) { create(:classroom) }
  let(:record) { build(:classroom_membership, classroom: classroom) }

  describe "#create? and #destroy?" do
    it "permits admin" do
      admin = create(:user, :admin)
      policy = described_class.new(admin, record)

      expect(policy.create?).to eq(true)
      expect(policy.destroy?).to eq(true)
    end

    it "permits a teacher member of the classroom" do
      teacher = create(:user, :teacher)
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      policy = described_class.new(teacher, record)

      expect(policy.create?).to eq(true)
      expect(policy.destroy?).to eq(true)
    end

    it "rejects a teacher outside the classroom" do
      teacher = create(:user, :teacher)
      policy = described_class.new(teacher, record)

      expect(policy.create?).to eq(false)
      expect(policy.destroy?).to eq(false)
    end

    it "rejects a student member of the classroom" do
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      policy = described_class.new(student, record)

      expect(policy.create?).to eq(false)
      expect(policy.destroy?).to eq(false)
    end

    it "rejects guest" do
      policy = described_class.new(nil, record)

      expect(policy.create?).to eq(false)
      expect(policy.destroy?).to eq(false)
    end
  end
end
