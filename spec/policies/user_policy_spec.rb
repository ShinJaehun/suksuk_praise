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

    it "permits an assigned teacher to view an inactive student record" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      create(:classroom_membership, user: student, classroom: classroom, role: "student", status: "inactive")

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

  describe "#destroy_student?" do
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let(:classroom) { create(:classroom) }

    it "permits admin for a student account" do
      admin = create(:user, :admin)

      expect(described_class.new(admin, student).destroy_student?).to eq(true)
    end

    it "permits a teacher for a student in the teacher's classroom" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      create(:classroom_membership, user: student, classroom: classroom, role: "student")

      expect(described_class.new(teacher, student).destroy_student?).to eq(true)
    end

    it "permits an assigned teacher to manage an inactive student account" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      create(:classroom_membership, user: student, classroom: classroom, role: "student", status: "inactive")

      expect(described_class.new(teacher, student).destroy_student?).to eq(true)
    end

    it "rejects a teacher for a student outside the teacher's classroom" do
      other_classroom = create(:classroom)
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      create(:classroom_membership, user: student, classroom: other_classroom, role: "student")

      expect(described_class.new(teacher, student).destroy_student?).to eq(false)
    end

    it "rejects a student for self" do
      expect(described_class.new(student, student).destroy_student?).to eq(false)
    end
  end

  describe "teacher status actions" do
    let(:school) { create(:school) }
    let(:manager) { create(:user, :teacher) }
    let(:member) { create(:user, :teacher) }

    before do
      create(:school_membership, :manager, school: school, user: manager)
      create(:school_membership, school: school, user: member)
    end

    it "allows admins to change teacher status" do
      admin = create(:user, :admin)
      expect(described_class.new(admin, member).deactivate_teacher?).to eq(true)
      member.update!(active: false)
      expect(described_class.new(admin, member).reactivate_teacher?).to eq(true)
    end

    it "allows a manager only for another same-school member" do
      expect(described_class.new(manager, member).deactivate_teacher?).to eq(true)
      expect(described_class.new(manager, manager).deactivate_teacher?).to eq(false)
      expect(described_class.new(member, manager).deactivate_teacher?).to eq(false)
      expect(described_class.new(manager, create(:user, :teacher)).deactivate_teacher?).to eq(false)
      expect(described_class.new(manager, create(:user, :student)).deactivate_teacher?).to eq(false)
    end
  end
end
