require "rails_helper"

RSpec.describe SchoolPolicy do
  let(:school) { create(:school) }

  it "allows an admin to create and update schools" do
    admin = create(:user, :admin)
    policy = described_class.new(admin, school)

    expect(policy.new?).to eq(true)
    expect(policy.create?).to eq(true)
    expect(policy.edit?).to eq(true)
    expect(policy.update?).to eq(true)
  end

  it "rejects teachers and students" do
    [create(:user, :teacher), create(:user, :student)].each do |user|
      policy = described_class.new(user, school)

      expect(policy.create?).to eq(false)
      expect(policy.update?).to eq(false)
    end
  end

  it "scopes all schools to admins and no schools to other roles" do
    school
    admin = create(:user, :admin)
    teacher = create(:user, :teacher)
    student = create(:user, :student)

    expect(described_class::Scope.new(admin, School).resolve).to contain_exactly(school)
    expect(described_class::Scope.new(teacher, School).resolve).to be_empty
    expect(described_class::Scope.new(student, School).resolve).to be_empty
  end
end
