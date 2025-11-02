class CouponTemplate < ApplicationRecord
  has_many :user_coupons, dependent: :restrict_with_exception
  belongs_to :created_by, class_name: "User"

  validates :title, presence: true
  validates :weight, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :bucket, presence: true, inclusion: { in: %w[personal library] }
  validates :title, uniqueness: {
    scope: %i[created_by_id bucket],
    case_sensitive: false,
    message: :already_in_bucket
  }

  scope :active, -> { where(active: true) }
  scope :by_bucket, ->(bucket) { where(bucket: bucket) }
  scope :owned_by, ->(user_id) { where(created_by_id: user_id) }
  scope :ordered_by_title, -> { order(:title) }
  scope :personal_for, ->(user) { owned_by(user.id).by_bucket("personal") }

  before_validation :zero_weight_if_inactive

  private

  def zero_weight_if_inactive
    self.weight = 0 if active == false
  end
end
