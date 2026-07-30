require 'rails_helper'

RSpec.describe Classrooms::IndexContext do
  let(:school) { create(:school) }

  it 'returns only the supplied classrooms in reverse creation order with schools loaded' do
    older = create(:classroom, school: school, created_at: 2.days.ago)
    newer = create(:classroom, school: school, created_at: 1.day.ago)
    create(:classroom, school: school, created_at: Time.current)
    scope = Classroom.where(id: [older.id, newer.id])

    classrooms = described_class.new(classrooms_scope: scope).classrooms.load

    expect(classrooms).to eq([newer, older])
    expect(classrooms).to all(satisfy { |classroom| classroom.association(:school).loaded? })
  end

  it 'counts active teacher users and returns at most three teacher previews with avatars loaded' do
    classroom = create(:classroom, school: school)
    teachers = 4.times.map do |index|
      create(:user, :teacher, name: "교사 #{index + 1}")
    end
    teachers.first.avatar.attach(
      io: StringIO.new('avatar'),
      filename: 'avatar.png',
      content_type: 'image/png'
    )
    teachers.each do |teacher|
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    end
    inactive_teacher = create(:user, :teacher, active: false)
    legacy_admin = create(:user, :admin)
    create(:classroom_membership, classroom: classroom, user: inactive_teacher, role: 'teacher')
    create(:classroom_membership, classroom: classroom, user: legacy_admin, role: 'teacher')
    outside_classroom = create(:classroom)
    outside_teacher = create(:user, :teacher)
    create(:classroom_membership, classroom: outside_classroom, user: outside_teacher, role: 'teacher')

    context = described_class.new(classrooms_scope: Classroom.where(id: classroom.id))
    previews = context.teacher_previews.fetch(classroom.id)

    expect(context.teacher_counts).to eq(classroom.id => 4)
    expect(previews).to eq(teachers.first(3))
    expect(previews).not_to include(inactive_teacher, legacy_admin, outside_teacher)
    expect(previews.first.association(:avatar_attachment)).to be_loaded
    expect(previews.first.avatar_attachment.association(:blob)).to be_loaded
  end

  it 'counts active student memberships and returns at most five student previews with avatars loaded' do
    classroom = create(:classroom, school: school)
    students = 6.times.map do |index|
      create(:user, :student, name: "학생 #{index + 1}")
    end
    students.first.avatar.attach(
      io: StringIO.new('avatar'),
      filename: 'avatar.png',
      content_type: 'image/png'
    )
    students.each do |student|
      create(:classroom_membership, classroom: classroom, user: student, role: 'student', status: 'active')
    end
    inactive_student = create(:user, :student)
    create(
      :classroom_membership,
      classroom: classroom,
      user: inactive_student,
      role: 'student',
      status: 'inactive'
    )
    outside_classroom = create(:classroom)
    outside_student = create(:user, :student)
    create(:classroom_membership, classroom: outside_classroom, user: outside_student, role: 'student')

    context = described_class.new(classrooms_scope: Classroom.where(id: classroom.id))
    previews = context.student_previews.fetch(classroom.id)

    expect(context.student_counts).to eq(classroom.id => 6)
    expect(previews).to eq(students.first(5))
    expect(previews).not_to include(inactive_student, outside_student)
    expect(previews.first.association(:avatar_attachment)).to be_loaded
    expect(previews.first.avatar_attachment.association(:blob)).to be_loaded
  end

  it 'returns empty collections for an empty scope' do
    context = described_class.new(classrooms_scope: Classroom.none)

    expect(context.classrooms).to be_empty
    expect(context.teacher_counts).to eq({})
    expect(context.teacher_previews).to eq({})
    expect(context.student_counts).to eq({})
    expect(context.student_previews).to eq({})
  end
end
