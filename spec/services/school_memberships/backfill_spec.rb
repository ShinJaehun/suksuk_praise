require "rails_helper"

RSpec.describe SchoolMemberships::Backfill do
  it "backfills teacher memberships idempotently while preserving managers and excluding students" do
    school = create(:school)
    classrooms = create_list(:classroom, 2, school: school)
    teacher = create(:user, :teacher)
    manager_membership = create(:school_membership, :manager, school: school)
    student = create(:user, :student)
    classrooms.each { |classroom| create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher) }
    create(:classroom_membership, classroom: classrooms.first, user: manager_membership.user, role: :teacher)
    create(:classroom_membership, classroom: classrooms.first, user: student, role: :student)

    first = described_class.call
    second = described_class.call

    expect(first.created).to eq(1)
    expect(second.created).to eq(0)
    expect(second.conflicts).to eq(0)
    expect(teacher.reload.school_membership).to be_member
    expect(manager_membership.reload).to be_manager
    expect(student.reload.school_membership).to be_nil
  end

  it "counts cross-school conflicts without changing memberships or assignments" do
    first_school = create(:school)
    other_classroom = create(:classroom, school: create(:school))
    membership = create(:school_membership, school: first_school)
    classroom_membership = create(:classroom_membership, classroom: other_classroom, user: membership.user, role: :teacher)

    result = described_class.call

    expect(result.conflicts).to eq(1)
    expect(membership.reload.school).to eq(first_school)
    expect(classroom_membership.reload).to be_persisted
  end
end
