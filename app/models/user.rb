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

  # 받았던 칭찬도 유저 삭제 시 함께 삭제
  has_many :given_compliments,
           class_name: "Compliment",
           foreign_key: :giver_id,
           dependent: :destroy,
           inverse_of: :giver

  has_many :received_compliments,
           class_name: "Compliment",
           foreign_key: :receiver_id,
           dependent: :destroy,
           inverse_of: :receiver

  has_many :user_coupons, dependent: :destroy
  has_many :coupon_templates, through: :user_coupons

  after_commit :setup_default_coupons_for_teacher, on: :create

  private

  def setup_default_coupons_for_teacher
    return unless teacher?
    CouponTemplates::AutoAdopter.setup_for_teacher!(self)
  end
end
