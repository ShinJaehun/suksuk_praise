require "rails_helper"

RSpec.describe UserPolicy do
  describe "#show?" do
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let(:classroom) { create(:classroom) }

    it "permits admin" do
      admin = create(:user, :admin)

      expect(described_class.new(admin, student).show?).to eq(true)
    end

    it "permits a teacher for a student in the teacher's classroom" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      create(:classroom_membership, user: student, classroom: classroom, role: "student")

      expect(described_class.new(teacher, student).show?).to eq(true)
    end

    it "rejects a teacher for a student outside the teacher's classroom" do
      other_classroom = create(:classroom)
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      create(:classroom_membership, user: student, classroom: other_classroom, role: "student")

      expect(described_class.new(teacher, student).show?).to eq(false)
    end

    it "permits a student for self" do
      expect(described_class.new(student, student).show?).to eq(true)
    end

    it "rejects a student for another student" do
      other_student = create(:user, :student)

      expect(described_class.new(student, other_student).show?).to eq(false)
    end
  end
end
