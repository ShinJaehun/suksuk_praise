class ClassroomMembership < ApplicationRecord
  belongs_to :user
  belongs_to :classroom

  enum role: { student: "student", teacher: "teacher" }
end
