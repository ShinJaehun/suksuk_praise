class CouponTemplate < ApplicationRecord
  has_many :user_coupons, dependent: :restrict_with_exception
  belongs_to :created_by, class_name: "User"

  validates :title, presence: true
  validates :weight, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :created_by, presence: true

  validates :bucket, presence: true, inclusion: { in: %w[personal library] }
  validates :title, uniqueness: {
    scope: %i[created_by_id bucket],
    case_sensitive: false,
    message: :already_in_bucket
  }
  validate :library_bucket_admin_only

  scope :active, -> { where(active: true) }
  scope :personal_for, ->(user) { where(created_by_id: user.id, bucket: "personal") }
  scope :library_public, -> { 
    joins(:created_by)
      .merge(User.where(role: "admin"))
      .where(bucket: "library", active: true)
      .order(:title)
  }

  def self.weighted_pick(relation = active)
    total = relation.sum(:weight)
    return nil if total <= 0

    ticket = rand(1..total)
    running = 0
    relation.find_each do |tpl|
      running += tpl.weight
      return tpl if ticket <= running
    end
    nil
  end

  private

  def library_bucket_admin_only
    return unless bucket == "library"

    # created_by가 아직 바인딩 안 됐을 수도 있어 created_by_id 기준으로 간단 가드
    owner_role =
      if association(:created_by).loaded? && created_by
        created_by.role
      else
        User.where(id: created_by_id).pick(:role)
      end

    if owner_role != "admin"
      errors.add(:bucket, :forbidden, message: "library 버킷은 관리자만 사용할 수 있습니다")
    end

    if owner_role.nil?
      errors.add(:created_by, :blank, message: "소유자가 필요합니다")
      return
    end
  end
end
