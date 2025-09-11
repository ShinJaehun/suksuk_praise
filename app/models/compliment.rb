class Compliment < ApplicationRecord
  belongs_to :giver, class_name: "User"
  belongs_to :receiver, class_name: "User"
  belongs_to :classroom

  validates :classroom, presence: true
  validates :given_at, presence: true
end
