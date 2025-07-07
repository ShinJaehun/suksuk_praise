class Classroom < ApplicationRecord
    has_many :classroom_memberships, dependent: :destroy
    has_many :users, through: :classroom_memberships

    def students
      users.merge(ClassroomMembership.where(role: "student"))
    end
end
