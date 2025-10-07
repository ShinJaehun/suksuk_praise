class Classroom < ApplicationRecord
    has_many :classroom_memberships, dependent: :destroy
    has_many :users, through: :classroom_memberships
    has_many :user_coupons, dependent: :destroy
    has_many :compliments, dependent: :destroy

    def students
      users.merge(ClassroomMembership.where(role: "student"))
    end
end
