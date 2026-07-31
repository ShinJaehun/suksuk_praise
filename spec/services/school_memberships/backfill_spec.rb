require "rails_helper"

RSpec.describe SchoolMemberships::Backfill do
  def insert_legacy_teacher_membership!(user:, classroom:)
    ClassroomMembership.insert!({
                                  user_id: user.id,
                                  classroom_id: classroom.id,
                                  role: 'teacher',
                                  status: 'active',
                                  student_number: nil,
                                  created_at: Time.current,
                                  updated_at: Time.current
                                })
  end

  it "backfills teacher memberships idempotently while preserving managers and excluding students" do
    school = create(:school)
    classrooms = create_list(:classroom, 2, school: school)
    teacher = create(:user, :teacher)
    manager_membership = create(:school_membership, :manager, school: school)
    student = create(:user, :student)
    classrooms.each do |classroom|
      insert_legacy_teacher_membership!(user: teacher, classroom: classroom)
    end
    create(:classroom_membership, classroom: classrooms.first, user: manager_membership.user, role: :teacher)
    create(:classroom_membership, classroom: classrooms.first, user: student, role: :student)
    expect(teacher.school_membership).to be_nil

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
    insert_legacy_teacher_membership!(user: membership.user, classroom: other_classroom)
    classroom_membership = ClassroomMembership.find_by!(
      classroom: other_classroom,
      user: membership.user
    )

    result = described_class.call

    expect(result.conflicts).to eq(1)
    expect(membership.reload.school).to eq(first_school)
    expect(classroom_membership.reload).to be_persisted
  end
end
