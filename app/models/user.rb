class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_secure_password :student_pin, validations: false

  GENDERS = %w[boy girl male female].freeze
  BOY_AVATAR_KEYS = (1..23).map { |number| format("boy%02d", number) }.freeze
  GIRL_AVATAR_KEYS = (1..17).map { |number| format("girl%02d", number) }.freeze
  TEACHER_MALE_AVATAR_KEYS = (1..8).map { |number| format("teacherM%02d", number) }.freeze
  TEACHER_FEMALE_AVATAR_KEYS = (1..6).map { |number| format("teacherF%02d", number) }.freeze
  ADMIN_AVATAR_KEYS = %w[admin].freeze
  STUDENT_AVATAR_KEYS = (BOY_AVATAR_KEYS + GIRL_AVATAR_KEYS).freeze
  TEACHER_AVATAR_KEYS = (TEACHER_MALE_AVATAR_KEYS + TEACHER_FEMALE_AVATAR_KEYS).freeze
  AVATAR_KEYS_BY_ROLE = {
    "student" => STUDENT_AVATAR_KEYS,
    "teacher" => TEACHER_AVATAR_KEYS,
    "admin" => (ADMIN_AVATAR_KEYS + TEACHER_AVATAR_KEYS).freeze
  }.freeze
  AVATAR_KEYS_BY_GENDER = {
    "boy" => BOY_AVATAR_KEYS,
    "girl" => GIRL_AVATAR_KEYS,
    "male" => TEACHER_MALE_AVATAR_KEYS,
    "female" => TEACHER_FEMALE_AVATAR_KEYS,
    "admin" => ADMIN_AVATAR_KEYS
  }.freeze
  AVATAR_KEYS = AVATAR_KEYS_BY_GENDER.values.flatten.freeze

  validates :name, presence: true, length: { maximum: 30 }
  validates :gender, inclusion: { in: GENDERS }, allow_nil: true
  validates :avatar_key, inclusion: { in: AVATAR_KEYS }, allow_nil: true, if: :will_save_change_to_avatar_key?
  validate :avatar_key_allowed_for_role, if: :will_save_change_to_avatar_key?
  validates :student_pin, format: { with: /\A\d{4}\z/, message: "must be 4 digits" }, allow_blank: true

  enum role: { student: "student", teacher: "teacher", admin: "admin" }
  has_one_attached :avatar

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

  has_many :sent_messages,
           class_name: "UserMessage",
           foreign_key: :sender_id,
           dependent: :destroy,
           inverse_of: :sender

  has_many :received_messages,
           class_name: "UserMessage",
           foreign_key: :recipient_id,
           dependent: :destroy,
           inverse_of: :recipient

  after_commit :setup_default_coupons_for_teacher, on: :create

  def self.avatar_keys_for(gender)
    AVATAR_KEYS_BY_GENDER.fetch(gender.to_s, [])
  end

  def self.avatar_keys_for_role(role)
    AVATAR_KEYS_BY_ROLE.fetch(role.to_s, [])
  end

  def student_pin_configured?
    student_pin_digest.present?
  end

  def default_student_pin?
    student_pin_configured? && authenticate_student_pin("1234")
  end

  private

  def avatar_key_allowed_for_role
    return if avatar_key.blank? || self.class.avatar_keys_for_role(role).include?(avatar_key)

    errors.add(:avatar_key, :inclusion)
  end

  def setup_default_coupons_for_teacher
    return unless teacher?
    CouponTemplates::AutoAdopter.setup_for_teacher!(self)
  end
end
