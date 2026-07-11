class School < ApplicationRecord
  has_many :classrooms, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 80 }
end
