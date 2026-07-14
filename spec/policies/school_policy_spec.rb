require "rails_helper"

RSpec.describe SchoolPolicy do
  let!(:school) { create(:school) }
  let!(:other_school) { create(:school) }

  describe "Scope" do
    it "returns all schools for an admin" do
      admin = create(:user, :admin)

      expect(described_class::Scope.new(admin, School).resolve).to contain_exactly(school, other_school)
    end

    it "returns only the member teacher's school" do
      teacher = create(:user, :teacher)
      create(:school_membership, school: school, user: teacher)

      expect(described_class::Scope.new(teacher, School).resolve).to contain_exactly(school)
    end

    it "returns only the manager teacher's school" do
      teacher = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: teacher)

      expect(described_class::Scope.new(teacher, School).resolve).to contain_exactly(school)
    end

    it "returns an empty relation for a teacher without a school and for a student" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)

      expect(described_class::Scope.new(teacher, School).resolve).to be_empty
      expect(described_class::Scope.new(student, School).resolve).to be_empty
    end
  end

  describe "permissions" do
    it "allows an admin to view and manage every school" do
      admin = create(:user, :admin)

      [school, other_school].each do |record|
        policy = described_class.new(admin, record)

        expect(policy.index?).to eq(true)
        expect(policy.show?).to eq(true)
        expect(policy.manage_operations?).to eq(true)
      end
    end

    it "allows a member to view only their school without managing operations" do
      teacher = create(:user, :teacher)
      create(:school_membership, school: school, user: teacher)

      own_policy = described_class.new(teacher, school)
      other_policy = described_class.new(teacher, other_school)

      expect(own_policy.index?).to eq(true)
      expect(own_policy.show?).to eq(true)
      expect(own_policy.manage_operations?).to eq(false)
      expect(other_policy.show?).to eq(false)
      expect(other_policy.manage_operations?).to eq(false)
    end

    it "allows a manager to view and manage operations only for their school" do
      teacher = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: teacher)

      own_policy = described_class.new(teacher, school)
      other_policy = described_class.new(teacher, other_school)

      expect(own_policy.index?).to eq(true)
      expect(own_policy.show?).to eq(true)
      expect(own_policy.manage_operations?).to eq(true)
      expect(other_policy.show?).to eq(false)
      expect(other_policy.manage_operations?).to eq(false)
    end

    it "rejects a teacher without a school and a student" do
      [create(:user, :teacher), create(:user, :student)].each do |user|
        policy = described_class.new(user, school)

        expect(policy.index?).to eq(false)
        expect(policy.show?).to eq(false)
        expect(policy.manage_operations?).to eq(false)
        expect(policy.manage_teachers?).to eq(false)
      end
    end

    it "allows only admins and managers of the record school to manage school teachers" do
      admin = create(:user, :admin)
      manager = create(:user, :teacher)
      member = create(:user, :teacher)
      other_manager = create(:user, :teacher)
      student = create(:user, :student)
      create(:school_membership, :manager, school: school, user: manager)
      create(:school_membership, school: school, user: member)
      create(:school_membership, :manager, school: other_school, user: other_manager)

      expect(described_class.new(admin, school).manage_teachers?).to eq(true)
      expect(described_class.new(manager, school).manage_teachers?).to eq(true)
      expect(described_class.new(member, school).manage_teachers?).to eq(false)
      expect(described_class.new(other_manager, school).manage_teachers?).to eq(false)
      expect(described_class.new(student, school).manage_teachers?).to eq(false)
      expect(described_class.new(nil, school).manage_teachers?).to be_falsey
    end

    it "keeps school creation, updates, and deletion admin-only" do
      admin_policy = described_class.new(create(:user, :admin), school)
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)
      manager_policy = described_class.new(manager, school)

      expect(admin_policy.create?).to eq(true)
      expect(admin_policy.update?).to eq(true)
      expect(admin_policy.destroy?).to eq(true)
      expect(manager_policy.create?).to eq(false)
      expect(manager_policy.update?).to eq(false)
      expect(manager_policy.destroy?).to eq(false)
    end
  end
end
