require "rails_helper"

RSpec.describe ClassroomPolicy do
  describe "Scope" do
    let(:school) { create(:school) }
    let(:other_school) { create(:school) }
    let!(:classroom) { create(:classroom, school: school) }
    let!(:other_classroom) { create(:classroom, school: other_school) }

    it "returns every classroom for an admin" do
      admin = create(:user, :admin)

      expect(Pundit.policy_scope!(admin, Classroom)).to contain_exactly(classroom, other_classroom)
    end

    it "returns every classroom in the manager school" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)

      expect(Pundit.policy_scope!(manager, Classroom)).to contain_exactly(classroom)
    end

    it "returns only assigned classrooms for a regular teacher" do
      teacher = create(:user, :teacher)
      create(:school_membership, school: school, user: teacher)
      assigned_classroom = create(:classroom, school: school)
      create(:classroom_membership, classroom: assigned_classroom, user: teacher, role: :teacher)

      expect(Pundit.policy_scope!(teacher, Classroom)).to contain_exactly(assigned_classroom)
    end

    it "keeps the student membership scope" do
      student = create(:user, :student)
      create(:classroom_membership, classroom: classroom, user: student, role: :student)

      expect(Pundit.policy_scope!(student, Classroom)).to contain_exactly(classroom)
    end
  end

  describe "#show?" do
    it "permits a manager to view an unassigned classroom in their school" do
      school = create(:school)
      manager = create(:user, :teacher)
      classroom = create(:classroom, school: school)
      create(:school_membership, :manager, school: school, user: manager)

      expect(described_class.new(manager, classroom).show?).to eq(true)
    end

    it "rejects a manager outside the classroom school" do
      manager = create(:user, :teacher)
      classroom = create(:classroom)
      create(:school_membership, :manager, school: create(:school), user: manager)

      expect(described_class.new(manager, classroom).show?).to eq(false)
    end
  end

  describe "#view_student_data?" do
    let(:school) { create(:school) }
    let(:classroom) { create(:classroom, school: school) }

    it "permits an admin" do
      expect(described_class.new(create(:user, :admin), classroom).view_student_data?).to eq(true)
    end

    it "permits a teacher assigned to the classroom" do
      teacher = create(:user, :teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")

      expect(described_class.new(teacher, classroom).view_student_data?).to eq(true)
    end

    it "rejects a teacher outside the classroom" do
      expect(described_class.new(create(:user, :teacher), classroom).view_student_data?).to eq(false)
    end

    it "rejects an unassigned school manager" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)

      expect(described_class.new(manager, classroom).view_student_data?).to eq(false)
    end

    it "permits a manager who is also assigned to the classroom" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)
      create(:classroom_membership, classroom: classroom, user: manager, role: "teacher")

      expect(described_class.new(manager, classroom).view_student_data?).to eq(true)
    end

    it "permits a student member of the classroom" do
      student = create(:user, :student)
      create(:classroom_membership, classroom: classroom, user: student, role: "student")

      expect(described_class.new(student, classroom).view_student_data?).to eq(true)
    end
  end

  describe "classroom operation permissions" do
    let(:school) { create(:school) }
    let(:classroom) { create(:classroom, school: school) }
    let(:manager) { create(:user, :teacher) }

    before do
      create(:school_membership, :manager, school: school, user: manager)
    end

    it "keeps settings update access for an unassigned manager but blocks teacher operations" do
      policy = described_class.new(manager, classroom)

      expect(policy.update?).to eq(true)
      expect(policy.manage_members?).to eq(false)
      expect(policy.create_compliment?).to eq(false)
      expect(policy.refresh_compliment_king?).to eq(false)
      expect(policy.draw_coupon?).to eq(false)
      expect(policy.destroy?).to eq(false)
    end

    it "combines manager access with existing classroom teacher permissions" do
      create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
      policy = described_class.new(manager, classroom)

      expect(policy.update?).to eq(true)
      expect(policy.manage_members?).to eq(true)
      expect(policy.create_compliment?).to eq(true)
      expect(policy.refresh_compliment_king?).to eq(true)
      expect(policy.draw_coupon?).to eq(true)
      expect(policy.destroy?).to eq(false)
    end
  end

  describe "settings permissions" do
    let(:school) { create(:school) }
    let(:classroom) { create(:classroom, school: school) }

    it "allows an admin to manage structure, operations, and members" do
      policy = described_class.new(create(:user, :admin), classroom)

      expect(policy.manage_structure?).to eq(true)
      expect(policy.manage_operations?).to eq(true)
      expect(policy.update?).to eq(true)
      expect(policy.manage_members?).to eq(true)
    end

    it "allows an unassigned school manager to manage only structure" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)
      policy = described_class.new(manager, classroom)

      expect(policy.manage_structure?).to eq(true)
      expect(policy.manage_operations?).to eq(false)
      expect(policy.update?).to eq(true)
      expect(policy.manage_members?).to eq(false)
    end

    it "combines structure and teacher permissions for an assigned school manager" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)
      create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
      policy = described_class.new(manager, classroom)

      expect(policy.manage_structure?).to eq(true)
      expect(policy.manage_operations?).to eq(true)
      expect(policy.update?).to eq(true)
      expect(policy.manage_members?).to eq(true)
    end

    it "allows an assigned regular teacher to manage operations and members only" do
      teacher = create(:user, :teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
      policy = described_class.new(teacher, classroom)

      expect(policy.manage_structure?).to eq(false)
      expect(policy.manage_operations?).to eq(true)
      expect(policy.update?).to eq(true)
      expect(policy.manage_members?).to eq(true)
    end

    it "rejects an unassigned teacher, student, and guest" do
      users = [create(:user, :teacher), create(:user, :student), nil]

      users.each do |user|
        policy = described_class.new(user, classroom)

        expect(policy.manage_structure?).to eq(false)
        expect(policy.manage_operations?).to eq(false)
        expect(policy.update?).to eq(false)
        expect(policy.manage_members?).to eq(false)
      end
    end
  end

  describe "#destroy?" do
    let(:school) { create(:school) }
    let(:classroom) { create(:classroom, school: school) }

    it "permits an admin" do
      expect(described_class.new(create(:user, :admin), classroom).destroy?).to eq(true)
    end

    it "rejects an assigned teacher" do
      teacher = create(:user, :teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")

      expect(described_class.new(teacher, classroom).destroy?).to eq(false)
    end

    it "rejects an unassigned teacher" do
      expect(described_class.new(create(:user, :teacher), classroom).destroy?).to eq(false)
    end

    it "rejects an unassigned school manager" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)

      expect(described_class.new(manager, classroom).destroy?).to eq(false)
    end

    it "rejects a school manager who is also an assigned teacher" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)
      create(:classroom_membership, classroom: classroom, user: manager, role: "teacher")

      expect(described_class.new(manager, classroom).destroy?).to eq(false)
    end

    it "rejects a student" do
      expect(described_class.new(create(:user, :student), classroom).destroy?).to eq(false)
    end

    it "rejects a guest" do
      expect(described_class.new(nil, classroom).destroy?).to eq(false)
    end
  end

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
