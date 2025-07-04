class Classroom < ApplicationRecord
    has_many :classroom_memberships, dependent: :destroy
    has_many :users, through: :classroom_memberships
end
