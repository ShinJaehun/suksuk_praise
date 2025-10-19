class CouponTemplate < ApplicationRecord
  has_many :user_coupons, dependent: :restrict_with_exception
  belongs_to :created_by, class_name: "User"

  validates :title, presence: true
  validates :weight, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :bucket, presence: true, inclusion: { in: %w[personal library] }
  validates :title, uniqueness: {
    scope: %i[created_by_id bucket],
    case_sensitive: false,
    message: :already_in_bucket
  }

  scope :active, -> { where(active: true) }
  scope :personal_for, ->(user) { where(created_by_id: user.id, bucket: "personal") }
  scope :library_for_admin, ->(user) { where(created_by_id: user.id, bucket: "library") }
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
end
