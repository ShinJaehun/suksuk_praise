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
  role: "admin"
)

User.create!(
  email: "t@t",
  password: "password",
  role: "teacher"
)

30.times do |i|
  User.create!(
    # name: "학생#{i + 1}",
    role: "student",
    # avatar: "avatars/avatar_#{(i % 30) + 1}.png",
    # points: 0,
    email: "student#{i + 1}@school.com", # Devise 필수
    password: "password"
  )
end