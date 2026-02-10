class CouponTemplate < ApplicationRecord
  has_many :user_coupons, dependent: :restrict_with_exception
  has_one_attached :image

  belongs_to :created_by, class_name: 'User'
  belongs_to :source_template, class_name: 'CouponTemplate', optional: true

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
  scope :personal_for, ->(user) { owned_by(user.id).by_bucket('personal') }

  # 새 교사 계정이 만들어질 때 개인 세트로 복제할 수 있는 라이브러리 쿠폰 목록
  scope :library_onboarding_candidates, lambda {
    joins(:created_by)
      .merge(User.where(role: 'admin'))
      .where(bucket: 'library', active: true)
  }
end
