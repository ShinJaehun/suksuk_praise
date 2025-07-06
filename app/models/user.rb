class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { student: "student", teacher: "teacher", admin: "admin" }

  has_many :classroom_memberships
  has_many :classrooms, through: :classroom_memberships

  has_many :given_compliments, class_name: "Compliment", foreign_key: :giver_id
  has_many :received_compliments, class_name: "Compliment", foreign_key: :receiver_id
end
