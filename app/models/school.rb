class School < ApplicationRecord
  has_many :classrooms, dependent: :restrict_with_error
  has_many :school_memberships, dependent: :restrict_with_error
  has_many :teachers, through: :school_memberships, source: :user

  validates :name, presence: true, length: { maximum: 80 }
end
