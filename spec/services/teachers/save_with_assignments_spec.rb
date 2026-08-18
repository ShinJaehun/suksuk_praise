require "rails_helper"

RSpec.describe Teachers::SaveWithAssignments do
  def call_service(teacher:, school:, classroom_ids:, attributes: {}, assignment_scope: :all)
    described_class.call(
      teacher: teacher,
      attributes: attributes,
      school: school,
      classroom_ids: classroom_ids,
      assignment_scope: assignment_scope
    )
  end

  it "creates a teacher with an active school and classrooms in that school" do
    school = create(:school)
    classrooms = create_list(:classroom, 2, school: school)
    teacher = build(:user, :teacher)

    result = call_service(
      teacher: teacher,
      school: school,
      classroom_ids: classrooms.map(&:id)
    )

    expect(result).to be_success
    expect(teacher).to be_persisted
    expect(teacher.school_membership).to have_attributes(school: school, role: "member")
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to match_array(classrooms.map(&:id))
  end

  it "updates teacher attributes" do
    teacher = create(:user, :teacher, name: "변경 전")

    result = call_service(
      teacher: teacher,
      attributes: { name: "변경 후" },
      school: nil,
      classroom_ids: []
    )

    expect(result).to be_success
    expect(teacher.reload.name).to eq("변경 후")
  end

  it "adds and removes classroom assignments in the same school" do
    school = create(:school)
    removed = create(:classroom, school: school)
    kept = create(:classroom, school: school)
    added = create(:classroom, school: school)
    teacher = create(:school_membership, school: school).user
    create(:classroom_membership, user: teacher, classroom: removed, role: :teacher)
    kept_membership = create(:classroom_membership, user: teacher, classroom: kept, role: :teacher)

    result = call_service(
      teacher: teacher,
      school: school,
      classroom_ids: [kept.id, added.id]
    )

    expect(result).to be_success
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(kept.id, added.id)
    expect(teacher.classroom_memberships.teacher.find_by(classroom: kept)).to eq(kept_membership)
  end

  it "uses assignment state loaded after locking a persisted teacher" do
    school = create(:school)
    initial = create(:classroom, school: school)
    concurrently_added = create(:classroom, school: school)
    requested = create(:classroom, school: school)
    teacher = create(:school_membership, school: school).user
    create(:classroom_membership, user: teacher, classroom: initial, role: :teacher)

    allow(teacher).to receive(:with_lock).and_wrap_original do |with_lock, *args, &block|
      create(
        :classroom_membership,
        user: teacher,
        classroom: concurrently_added,
        role: :teacher
      )
      with_lock.call(*args, &block)
    end

    result = call_service(
      teacher: teacher,
      school: school,
      classroom_ids: [requested.id]
    )

    expect(result).to be_success
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(requested.id)
  end

  it "allows multiple classrooms in the same school" do
    school = create(:school)
    classrooms = create_list(:classroom, 3, school: school)
    teacher = create(:school_membership, school: school).user

    result = call_service(
      teacher: teacher,
      school: school,
      classroom_ids: classrooms.map(&:id)
    )

    expect(result).to be_success
    expect(teacher.classroom_memberships.teacher.count).to eq(3)
  end

  it "moves a teacher to another school and replaces classroom assignments" do
    old_school = create(:school)
    new_school = create(:school)
    old_classroom = create(:classroom, school: old_school)
    new_classroom = create(:classroom, school: new_school)
    teacher = create(:school_membership, school: old_school).user
    old_assignment = create(:classroom_membership, user: teacher, classroom: old_classroom, role: :teacher)

    result = call_service(
      teacher: teacher,
      school: new_school,
      classroom_ids: [new_classroom.id]
    )

    expect(result).to be_success
    expect(teacher.reload.school).to eq(new_school)
    expect(ClassroomMembership.exists?(old_assignment.id)).to eq(false)
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(new_classroom.id)
  end

  it "resets manager to member when the school changes" do
    membership = create(:school_membership, :manager)
    new_school = create(:school)

    result = call_service(
      teacher: membership.user,
      school: new_school,
      classroom_ids: []
    )

    expect(result).to be_success
    expect(membership.reload).to have_attributes(school: new_school, role: "member")
  end

  it "preserves manager in the same school" do
    membership = create(:school_membership, :manager)

    result = call_service(
      teacher: membership.user,
      school: membership.school,
      classroom_ids: []
    )

    expect(result).to be_success
    expect(membership.reload).to be_manager
  end

  it "removes the school membership and assignments when school is nil" do
    membership = create(:school_membership)
    classroom = create(:classroom, school: membership.school)
    assignment = create(:classroom_membership, user: membership.user, classroom: classroom, role: :teacher)

    result = call_service(
      teacher: membership.user,
      school: nil,
      classroom_ids: []
    )

    expect(result).to be_success
    expect(SchoolMembership.exists?(membership.id)).to eq(false)
    expect(ClassroomMembership.exists?(assignment.id)).to eq(false)
  end

  it "rejects classrooms when school is nil" do
    classroom = create(:classroom)
    teacher = create(:user, :teacher)

    result = call_service(
      teacher: teacher,
      school: nil,
      classroom_ids: [classroom.id]
    )

    expect(result).not_to be_success
    expect(teacher.errors.full_messages).to include(
      I18n.t("admin.teachers.errors.school_required_for_classrooms")
    )
  end

  it "rejects classrooms from another school" do
    school = create(:school)
    other_classroom = create(:classroom)
    teacher = create(:user, :teacher)

    result = call_service(
      teacher: teacher,
      school: school,
      classroom_ids: [other_classroom.id]
    )

    expect(result).not_to be_success
    expect(teacher.errors.full_messages).to include(
      I18n.t("admin.teachers.errors.classroom_school_mismatch")
    )
  end

  it "rejects nonexistent classroom ids" do
    teacher = create(:user, :teacher)

    result = call_service(
      teacher: teacher,
      school: create(:school),
      classroom_ids: [Classroom.maximum(:id).to_i + 10_000]
    )

    expect(result).not_to be_success
    expect(teacher.errors.full_messages).to include(
      I18n.t("admin.teachers.errors.classroom_not_found")
    )
  end

  it "rejects a newly selected inactive school" do
    teacher = create(:user, :teacher)

    result = call_service(
      teacher: teacher,
      school: create(:school, active: false),
      classroom_ids: []
    )

    expect(result).not_to be_success
    expect(teacher.errors.full_messages).to include(I18n.t("school_status.inactive_school"))
  end

  it "allows keeping an existing inactive school without adding assignments" do
    inactive_school = create(:school, active: false)
    membership = create(:school_membership, school: inactive_school)

    result = call_service(
      teacher: membership.user,
      attributes: { name: "수정된 교사" },
      school: membership.school,
      classroom_ids: []
    )

    expect(result).to be_success
    expect(membership.user.reload.name).to eq("수정된 교사")
    expect(membership.reload.school).to eq(inactive_school)
  end

  it "rejects adding an assignment to an existing inactive school" do
    inactive_school = create(:school, active: false)
    existing_classroom = create(:classroom, school: inactive_school)
    added_classroom = create(:classroom, school: inactive_school)
    membership = create(:school_membership, school: inactive_school)
    assignment = create(
      :classroom_membership,
      user: membership.user,
      classroom: existing_classroom,
      role: :teacher
    )

    result = call_service(
      teacher: membership.user,
      school: inactive_school,
      classroom_ids: [existing_classroom.id, added_classroom.id]
    )

    expect(result).not_to be_success
    expect(membership.user.classroom_memberships.teacher.pluck(:id)).to contain_exactly(assignment.id)
  end

  it "rolls back assignment and school changes when teacher attributes fail" do
    old_school = create(:school)
    new_school = create(:school)
    old_classroom = create(:classroom, school: old_school)
    new_classroom = create(:classroom, school: new_school)
    membership = create(:school_membership, :manager, school: old_school)
    assignment = create(
      :classroom_membership,
      user: membership.user,
      classroom: old_classroom,
      role: :teacher
    )

    result = call_service(
      teacher: membership.user,
      attributes: { name: "" },
      school: new_school,
      classroom_ids: [new_classroom.id]
    )

    expect(result).not_to be_success
    expect(membership.reload).to have_attributes(school: old_school, role: "manager")
    expect(membership.user.classroom_memberships.teacher.pluck(:id)).to contain_exactly(assignment.id)
  end

  it "rejects a non-teacher user" do
    student = create(:user, :student)

    result = call_service(
      teacher: student,
      school: create(:school),
      classroom_ids: []
    )

    expect(result).not_to be_success
    expect(student.errors.full_messages).to include(
      I18n.t("admin.teachers.errors.teacher_required")
    )
  end
end
