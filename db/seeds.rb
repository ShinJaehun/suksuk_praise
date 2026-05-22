# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

demo_student_pin = "1234" if Rails.env.development? || Rails.env.test?

admin_user = User.find_or_initialize_by(email: 'a@a')
admin_user.assign_attributes(
  email: 'a@a',
  password: 'password',
  name: '관리자에이',
  role: 'admin',
  default_avatar_index: rand(1..32)
)
admin_user.save!

teacherB = User.find_or_initialize_by(email: 'b@b')
teacherB.assign_attributes(
  email: 'b@b',
  password: 'password',
  name: '티쳐비',
  role: 'teacher',
  default_avatar_index: rand(1..32)
)
teacherB.save!

teacherT = User.find_or_initialize_by(email: 't@t')
teacherT.assign_attributes(
  email: 't@t',
  password: 'password',
  name: '티쳐티',
  role: 'teacher',
  default_avatar_index: rand(1..32)
)
teacherT.save!

students = 30.times.map do |i|
  student = User.find_or_initialize_by(email: "student#{i + 1}@school.com")
  attrs = {
    name: "학생#{i + 1}",
    role: 'student',
    default_avatar_index: rand(1..32),
    points: 0,
    email: "student#{i + 1}@school.com", # Devise 필수
    password: 'password'
  }
  attrs[:student_pin] = demo_student_pin if demo_student_pin.present?
  student.assign_attributes(attrs)
  student.save!
  student
end

classroom1 = Classroom.find_or_create_by!(name: '1반')
classroom2 = Classroom.find_or_create_by!(name: '2반')

ClassroomMembership.find_or_create_by!(
  user: teacherT,
  classroom: classroom1,
  role: 'teacher'
)

ClassroomMembership.find_or_create_by!(
  user: teacherB,
  classroom: classroom2,
  role: 'teacher'
)

students.each do |student|
  ClassroomMembership.find_or_create_by!(
    user: student,
    classroom: classroom1,
    role: 'student'
  )
end

if demo_student_pin.present?
  User.student.find_each do |student|
    student.update!(student_pin: demo_student_pin)
  end
end

admin = User.find_by(role: 'admin') # 이미 위에서 생성됨

templates = [
  { title: '쫀득 마이쭈', weight: 30, active: true, default_image_key: 'coupon_templates/mychew.png' },
  { title: '달콤 초콜릿', weight: 30, active: true, default_image_key: 'coupon_templates/chocolate.png' },
  { title: '좋아하는 자리에서 식사하기', weight: 30, active: true, default_image_key: 'coupon_templates/lunch_seat.png' },
  { title: '일주일간 자리 바꾸기', weight: 10, active: true, default_image_key: 'coupon_templates/swap.png' }
]

templates.each do |attrs|
  t = CouponTemplate.find_or_initialize_by(
    title: attrs[:title],
    created_by_id: admin.id,
    bucket: 'library'
  )
  t.assign_attributes(attrs.merge(bucket: 'library'))
  t.save!
end
