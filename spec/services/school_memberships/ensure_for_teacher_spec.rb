require "rails_helper"

RSpec.describe SchoolMemberships::EnsureForTeacher do
  it "creates one member membership for repeated assignments in the same school" do
    teacher = create(:user, :teacher)
    school = create(:school)

    2.times { described_class.call(teacher: teacher, school: school) }

    expect(teacher.reload.school_membership).to have_attributes(school: school, role: "member")
    expect(SchoolMembership.where(user: teacher).count).to eq(1)
  end

  it "does not demote an existing manager" do
    membership = create(:school_membership, :manager)

    described_class.call(teacher: membership.user, school: membership.school)

    expect(membership.reload).to be_manager
  end

  it "returns a conflict without changing a membership from another school" do
    membership = create(:school_membership, :manager)
    other_school = create(:school)
    original_school_id = membership.school_id

    result = described_class.call(teacher: membership.user, school: other_school)

    expect(result).to eq(:conflict)
    expect(membership.reload).to have_attributes(school_id: original_school_id, role: "manager")
  end

  it "returns existing after a unique race creates the same-school membership" do
    teacher = create(:user, :teacher)
    school = create(:school)
    raced_membership = build_stubbed(:school_membership, user: teacher, school: school)
    allow(SchoolMembership).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
    allow(SchoolMembership).to receive(:find_by).with(user_id: teacher.id).and_return(raced_membership)

    expect(described_class.call(teacher: teacher, school: school)).to eq(:existing)
  end

  it "returns conflict after a unique race creates another-school membership" do
    teacher = create(:user, :teacher)
    school = create(:school)
    raced_membership = build_stubbed(:school_membership, user: teacher, school: create(:school))
    allow(SchoolMembership).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
    allow(SchoolMembership).to receive(:find_by).with(user_id: teacher.id).and_return(raced_membership)

    expect(described_class.call(teacher: teacher, school: school)).to eq(:conflict)
  end

  it "does not create memberships for students or missing schools" do
    expect do
      described_class.call(teacher: create(:user, :student), school: create(:school))
      described_class.call(teacher: create(:user, :teacher), school: nil)
    end.not_to change(SchoolMembership, :count)
  end
end
