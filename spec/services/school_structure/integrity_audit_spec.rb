require 'rails_helper'

RSpec.describe SchoolStructure::IntegrityAudit do
  def insert_classroom_membership!(user:, classroom:, role:, student_number: nil)
    now = Time.current

    ClassroomMembership.insert!({
                                  user_id: user.id,
                                  classroom_id: classroom.id,
                                  role: role,
                                  status: 'active',
                                  student_number: student_number,
                                  created_at: now,
                                  updated_at: now
                                })
  end

  def insert_school_membership!(user:, school:)
    now = Time.current

    SchoolMembership.insert!({
                               user_id: user.id,
                               school_id: school.id,
                               role: SchoolMembership.roles.fetch('member'),
                               created_at: now,
                               updated_at: now
                             })
  end

  it "is clean for a teacher assigned to classrooms in the teacher's school" do
    school = create(:school)
    teacher = create(:user, :teacher)
    create(:school_membership, user: teacher, school: school)
    create_list(:classroom, 2, school: school).each do |classroom|
      create(:classroom_membership, user: teacher, classroom: classroom, role: 'teacher')
    end

    result = described_class.call

    expect(result).to be_clean
    expect(result.issue_count).to eq(0)
  end

  it 'finds a teacher assignment without a school membership' do
    teacher = create(:user, :teacher)
    membership = create(:classroom_membership, user: teacher, role: 'teacher')

    result = described_class.call

    expect(result.count_for(:teacher_without_school)).to eq(1)
    expect(result.samples_for(:teacher_without_school)).to include(
      include('classroom_membership_id' => membership.id, 'user_id' => teacher.id)
    )
  end

  it 'finds a teacher assigned to a classroom in another school' do
    teacher_school = create(:school)
    teacher = create(:user, :teacher)
    school_membership = create(:school_membership, user: teacher, school: teacher_school)
    membership = create(
      :classroom_membership,
      user: teacher,
      classroom: create(:classroom),
      role: 'teacher'
    )

    result = described_class.call

    expect(result.count_for(:teacher_classroom_school_mismatch)).to eq(1)
    expect(result.samples_for(:teacher_classroom_school_mismatch)).to include(
      include(
        'classroom_membership_id' => membership.id,
        'teacher_school_id' => teacher_school.id,
        'school_membership_id' => school_membership.id
      )
    )
  end

  it 'finds a teacher membership with a student number' do
    school = create(:school)
    teacher = create(:user, :teacher)
    create(:school_membership, user: teacher, school: school)
    membership = create(
      :classroom_membership,
      user: teacher,
      classroom: create(:classroom, school: school),
      role: 'teacher',
      student_number: 7
    )

    result = described_class.call

    expect(result.count_for(:teacher_membership_with_student_number)).to eq(1)
    expect(result.samples_for(:teacher_membership_with_student_number)).to include(
      include('classroom_membership_id' => membership.id, 'student_number' => 7)
    )
  end

  it 'finds classroom membership roles that do not match user roles' do
    teacher_as_student = create(:user, :teacher)
    student_as_teacher = create(:user, :student)
    insert_classroom_membership!(
      user: teacher_as_student,
      classroom: create(:classroom),
      role: 'student'
    )
    insert_classroom_membership!(
      user: student_as_teacher,
      classroom: create(:classroom),
      role: 'teacher'
    )

    result = described_class.call

    expect(result.count_for(:role_mismatch)).to eq(2)
    expect(result.samples_for(:role_mismatch).map { |sample| sample['user_id'] })
      .to contain_exactly(teacher_as_student.id, student_as_teacher.id)
  end

  it 'finds a teacher assigned to classrooms across multiple schools' do
    first_school = create(:school)
    second_school = create(:school)
    teacher = create(:user, :teacher)
    create(:school_membership, user: teacher, school: first_school)
    [first_school, second_school].each do |school|
      create(
        :classroom_membership,
        user: teacher,
        classroom: create(:classroom, school: school),
        role: 'teacher'
      )
    end

    result = described_class.call

    expect(result.count_for(:teacher_assigned_across_multiple_schools)).to eq(1)
    expect(result.samples_for(:teacher_assigned_across_multiple_schools)).to include(
      'user_id' => teacher.id,
      'classroom_school_ids' => [first_school.id, second_school.id].sort
    )
  end

  it 'finds a school membership whose user is not a teacher' do
    student = create(:user, :student)
    school = create(:school)
    insert_school_membership!(user: student, school: school)

    result = described_class.call

    expect(result.count_for(:invalid_school_membership_user_role)).to eq(1)
    expect(result.samples_for(:invalid_school_membership_user_role)).to include(
      include('user_id' => student.id, 'teacher_school_id' => school.id, 'user_role' => 'student')
    )
  end

  it 'limits samples without changing the total issue count' do
    2.times do
      create(:classroom_membership, user: create(:user, :teacher), role: 'teacher')
    end

    result = described_class.call(sample_limit: 1)

    expect(result.count_for(:teacher_without_school)).to eq(2)
    expect(result.samples_for(:teacher_without_school).size).to eq(1)
  end
end
