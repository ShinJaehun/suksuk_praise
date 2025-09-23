class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :name, presence: true, length: { maximum: 30 }

  enum role: { student: "student", teacher: "teacher", admin: "admin" }

  # 교실 멤버십은 유저 삭제 시 같이 삭제(조인 테이블)
  has_many :classroom_memberships, dependent: :destroy
  has_many :classrooms, through: :classroom_memberships


  # 칭찬 기록은 남기되 당사자 삭제 시 참조만 끊기(선호안)
  has_many :given_compliments,
           class_name: "Compliment",
           foreign_key: :giver_id,
           dependent: :nullify,
           inverse_of: :giver

  has_many :received_compliments,
           class_name: "Compliment",
           foreign_key: :receiver_id,
           dependent: :nullify,
           inverse_of: :receiver

  has_many :user_coupons, dependent: :nullify

  has_many :coupon_templates, through: :user_coupons
end
