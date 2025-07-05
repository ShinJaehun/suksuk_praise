# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

User.create!(
  email: "a@a",
  password: "password",
  name: "관리자에이",
  role: "admin"
)

teacher = User.create!(
  email: "t@t",
  password: "password",
  name: "티쳐티",
  role: "teacher"
)

students = 30.times.map do |i|
  User.create!(
    name: "학생#{i + 1}",
    role: "student",
    avatar: "avatars/avatar_#{(i % 30) + 1}.png",
    points: 0,
    email: "student#{i + 1}@school.com", # Devise 필수
    password: "password"
  )
end

classroom1 = Classroom.create!(name: "1반")

ClassroomMembership.create!(
  user: teacher,
  classroom: classroom1,
  role: "teacher"
)

students.each do |student|
  ClassroomMembership.create!(
    user: student,
    classroom: classroom1,
    role: "student"
  )
end
