class ClassroomMembership < ApplicationRecord
  belongs_to :user
  belongs_to :classroom

  enum role: { student: "student", teacher: "teacher" }
  enum :status, { active: "active", inactive: "inactive" }
end
