require "rails_helper"

RSpec.describe ComplimentPolicy do
  let(:classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }
  let(:student) { create(:user, :student) }
  let(:compliment) { create(:compliment, classroom: classroom, giver: teacher, receiver: student) }

  before do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    create(:classroom_membership, user: student, classroom: classroom, role: "student")
  end

  describe "#create?" do
    it "permits admin" do
      admin = create(:user, :admin)

      expect(described_class.new(admin, compliment).create?).to eq(true)
    end

    it "permits a teacher of the compliment classroom" do
      expect(described_class.new(teacher, compliment).create?).to eq(true)
    end

    it "rejects a teacher outside the compliment classroom" do
      outsider = create(:user, :teacher)

      expect(described_class.new(outsider, compliment).create?).to eq(false)
    end

    it "rejects a student" do
      expect(described_class.new(student, compliment).create?).to eq(false)
    end

    it "rejects guest" do
      expect(described_class.new(nil, compliment).create?).to eq(false)
    end
  end

  describe "#show?" do
    it "permits admin" do
      admin = create(:user, :admin)

      expect(described_class.new(admin, compliment).show?).to eq(true)
    end

    it "permits a classroom teacher member" do
      expect(described_class.new(teacher, compliment).show?).to eq(true)
    end

    it "permits the receiver student classroom member" do
      expect(described_class.new(student, compliment).show?).to eq(true)
    end

    it "rejects a teacher outside the classroom" do
      outsider = create(:user, :teacher)

      expect(described_class.new(outsider, compliment).show?).to eq(false)
    end

    it "rejects a student outside the classroom" do
      outsider = create(:user, :student)

      expect(described_class.new(outsider, compliment).show?).to eq(false)
    end
  end

  describe "#update? and #destroy?" do
    it "permits admin" do
      admin = create(:user, :admin)
      policy = described_class.new(admin, compliment)

      expect(policy.update?).to eq(true)
      expect(policy.destroy?).to eq(true)
    end

    it "permits a teacher of the compliment classroom" do
      policy = described_class.new(teacher, compliment)

      expect(policy.update?).to eq(true)
      expect(policy.destroy?).to eq(true)
    end

    it "rejects a student" do
      policy = described_class.new(student, compliment)

      expect(policy.update?).to eq(false)
      expect(policy.destroy?).to eq(false)
    end
  end
end
