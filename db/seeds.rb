# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

#demo_student_pin = '1234' if Rails.env.development? || Rails.env.test?
#
#def pick_demo_avatar_key(gender, used_avatar_keys)
#  pool = existing_demo_avatar_keys(User.avatar_keys_for(gender))
#  available = pool - used_avatar_keys
#  avatar_key = available.sample || pool.sample
#
#  used_avatar_keys << avatar_key if avatar_key.present?
#  avatar_key
#end
#
#def existing_demo_avatar_keys(keys)
#  keys.select { |key| Rails.root.join("app/assets/images/avatars/#{key}.png").exist? }
#end
#
#def pick_existing_demo_avatar_key(gender, fallback_key)
#  existing_demo_avatar_keys(User.avatar_keys_for(gender)).sample || fallback_key
#end
#
#admin_user = User.find_or_initialize_by(email: 'a@a')
#admin_user.assign_attributes(
#  email: 'a@a',
#  password: 'password',
#  name: '관리자에이',
#  role: 'admin',
#  avatar_key: 'admin'
#)
#admin_user.save!
#
#teacherB = User.find_or_initialize_by(email: 'b@b')
#teacherB.assign_attributes(
#  email: 'b@b',
#  password: 'password',
#  name: '티쳐비',
#  role: 'teacher',
#  gender: 'female',
#  avatar_key: pick_existing_demo_avatar_key('female', 'teacherF01')
#)
#teacherB.save!
#
#teacherT = User.find_or_initialize_by(email: 't@t')
#teacherT.assign_attributes(
#  email: 't@t',
#  password: 'password',
#  name: '티쳐티',
#  role: 'teacher',
#  gender: 'male',
#  avatar_key: pick_existing_demo_avatar_key('male', 'teacherM01')
#)
#teacherT.save!
#
#student_genders = (Array.new(15, 'boy') + Array.new(15, 'girl')).shuffle
#used_student_avatar_keys = []
#
#students = 30.times.map do |i|
#  student = User.where(role: 'student', name: "학생#{i + 1}").first_or_initialize
#  gender = student_genders[i] || (i.even? ? 'boy' : 'girl')
#  avatar_key = pick_demo_avatar_key(gender, used_student_avatar_keys)
#
#  attrs = {
#    name: "학생#{i + 1}",
#    role: 'student',
#    gender: gender,
#    avatar_key: avatar_key,
#    points: 0
#  }
#  attrs[:student_pin] = demo_student_pin if demo_student_pin.present?
#  student.assign_attributes(attrs)
#  student.save!
#  student
#end
#
#classroom1 = Classroom.find_or_create_by!(name: '1반')
#classroom2 = Classroom.find_or_create_by!(name: '2반')
#
#ClassroomMembership.find_or_create_by!(
#  user: teacherT,
#  classroom: classroom1,
#  role: 'teacher'
#)
#
#ClassroomMembership.find_or_create_by!(
#  user: teacherB,
#  classroom: classroom2,
#  role: 'teacher'
#)
#
#students.each do |student|
#  ClassroomMembership.find_or_create_by!(
#    user: student,
#    classroom: classroom1,
#    role: 'student'
#  )
#end
#
#if demo_student_pin.present?
#  User.student.find_each do |student|
#    student.update!(student_pin: demo_student_pin)
#  end
#end
#
# frozen_string_literal: true

# 개발 및 테스트 환경용 기본 데이터
#
# 새 데이터베이스:
#   bin/rails db:setup
#
# 기존 데이터베이스:
#   bin/rails db:seed
#
# 여러 번 실행해도 같은 기본 데이터를 재사용하도록 작성한다.

unless Rails.env.development? || Rails.env.test?
  puts "Demo seeds are only available in development and test environments."
  return
end

demo_password = "password"
demo_student_pin = "1234"

def existing_seed_avatar_keys(keys)
  keys.select do |key|
    Rails.root.join("app/assets/images/avatars/#{key}.png").exist?
  end
end

def first_seed_avatar_key(gender, fallback)
  existing_seed_avatar_keys(User.avatar_keys_for(gender)).first || fallback
end

def seed_student_avatar_key(gender, index)
  available_keys = existing_seed_avatar_keys(User.avatar_keys_for(gender))
  return if available_keys.empty?

  available_keys[index % available_keys.length]
end

def seed_account!(
  email:,
  name:,
  role:,
  password:,
  gender: nil,
  avatar_key: nil
)
  user = User.find_or_initialize_by(email: email)

  user.assign_attributes(
    name: name,
    role: role,
    gender: gender,
    avatar_key: avatar_key,
    password: password,
    password_confirmation: password
  )

  user.save!
  user
end

def seed_student!(
  name:,
  gender:,
  avatar_key:,
  student_pin:
)
  student = User
    .where(role: "student", name: name)
    .first_or_initialize

  student.assign_attributes(
    name: name,
    role: "student",
    gender: gender,
    avatar_key: avatar_key,
    points: 0,
    student_pin: student_pin
  )

  student.save!
  student
end

def seed_classroom_membership!(
  user:,
  classroom:,
  role:
)
  membership = ClassroomMembership.find_or_initialize_by(
    user: user,
    classroom: classroom
  )

  membership.assign_attributes(
    role: role,
    status: "active"
  )

  membership.save!
  membership
end

def seed_students!(
  classroom:,
  count:,
  name_prefix:,
  student_pin:
)
  gender_indexes = {
    "boy" => 0,
    "girl" => 0
  }

  count.times.map do |index|
    gender = index.even? ? "boy" : "girl"
    avatar_index = gender_indexes.fetch(gender)
    gender_indexes[gender] += 1

    student = seed_student!(
      name: "#{name_prefix} 학생 #{format('%02d', index + 1)}",
      gender: gender,
      avatar_key: seed_student_avatar_key(gender, avatar_index),
      student_pin: student_pin
    )

    # 학생은 동시에 하나의 활성 교실에만 소속될 수 있다.
    ClassroomMembership
      .where(
        user: student,
        role: "student",
        status: "active"
      )
      .where.not(classroom: classroom)
      .update_all(
        status: "inactive",
        updated_at: Time.current
      )

    seed_classroom_membership!(
      user: student,
      classroom: classroom,
      role: "student"
    )

    student
  end
end

puts "== 관리자 계정 생성 =="

admin = seed_account!(
  email: "a@a",
  name: "개발 관리자",
  role: "admin",
  password: demo_password,
  avatar_key: "admin"
)

puts "== 관리자 쿠폰 라이브러리 생성 =="

CouponTemplates::DefaultLibrarySeeder.call!(admin: admin)

puts "== 교사 계정 생성 =="

school_manager = seed_account!(
  email: "manager@example.com",
  name: "학교 관리자 교사",
  role: "teacher",
  password: demo_password,
  gender: "male",
  avatar_key: first_seed_avatar_key(
    "male",
    "teacherM01"
  )
)

classroom_teacher = seed_account!(
  email: "teacher@example.com",
  name: "4학년 1반 담임",
  role: "teacher",
  password: demo_password,
  gender: "female",
  avatar_key: first_seed_avatar_key(
    "female",
    "teacherF01"
  )
)

puts "== 학교 생성 =="

school = School.find_or_initialize_by(
  name: "쑥쑥초등학교"
)

school.save!

puts "== 학교 교사 소속 생성 =="

manager_school_membership =
  SchoolMembership.find_or_initialize_by(
    user: school_manager
  )

manager_school_membership.assign_attributes(
  school: school,
  role: "manager"
)

manager_school_membership.save!

teacher_school_membership =
  SchoolMembership.find_or_initialize_by(
    user: classroom_teacher
  )

teacher_school_membership.assign_attributes(
  school: school,
  role: "member"
)

teacher_school_membership.save!

puts "== 교실 생성 =="

classroom = Classroom.find_or_initialize_by(
  school: school,
  grade: 4,
  name: "1반"
)

classroom.assign_attributes(
  daily_compliment_king_enabled: true,
  weekly_compliment_king_enabled: true,
  monthly_compliment_king_enabled: true,
  message_policy: "student_initiated"
)

classroom.save!

empty_classroom = Classroom.find_or_initialize_by(
  school: school,
  grade: 4,
  name: "2반"
)

empty_classroom.assign_attributes(
  daily_compliment_king_enabled: true,
  weekly_compliment_king_enabled: false,
  monthly_compliment_king_enabled: false,
  message_policy: "replies_only"
)

empty_classroom.save!

puts "== 교실 담당 교사 배정 =="

seed_classroom_membership!(
  user: school_manager,
  classroom: classroom,
  role: "teacher"
)

seed_classroom_membership!(
  user: classroom_teacher,
  classroom: classroom,
  role: "teacher"
)

seed_classroom_membership!(
  user: school_manager,
  classroom: empty_classroom,
  role: "teacher"
)

puts "== 학생 25명 생성 =="

students = seed_students!(
  classroom: classroom,
  count: 25,
  name_prefix: "4-1",
  student_pin: demo_student_pin
)

puts "== 교사 개인 쿠폰 생성 =="

# 교사 계정 생성 시점에는 관리자 라이브러리 쿠폰이 없었을 수 있다.
# 라이브러리 쿠폰 생성 후 자동 채택을 다시 실행한다.
[school_manager, classroom_teacher].each do |teacher|
  CouponTemplates::AutoAdopter.setup_for_teacher!(teacher)
end

puts "== 교사 맞춤 칭찬 생성 =="

compliment_preset_titles = [
  "친구를 도와주었어요",
  "수업에 적극적으로 참여했어요",
  "약속을 잘 지켰어요",
  "끝까지 노력했어요",
  "바른 말과 행동을 실천했어요"
]

[school_manager, classroom_teacher].each do |teacher|
  compliment_preset_titles.each_with_index do |title, index|
    preset = ComplimentPreset
      .where(user: teacher)
      .where("lower(title) = ?", title.downcase)
      .first_or_initialize

    preset.assign_attributes(
      title: title,
      position: index,
      active: true
    )

    preset.save!
  end
end

puts
puts "========================================"
puts "Seed 데이터 생성 완료"
puts "========================================"
puts
puts "관리자"
puts "  이메일: a@a"
puts "  비밀번호: #{demo_password}"
puts
puts "학교 관리자 교사"
puts "  이메일: manager@example.com"
puts "  비밀번호: #{demo_password}"
puts
puts "담임 교사"
puts "  이메일: teacher@example.com"
puts "  비밀번호: #{demo_password}"
puts
puts "학생"
puts "  학교: #{school.name}"
puts "  교실: #{classroom.grade}학년 #{classroom.name}"
puts "  인원: #{students.count}명"
puts "  PIN: #{demo_student_pin}"
puts
puts "학생 로그인 토큰"
puts "  #{classroom.student_login_token}"
puts
