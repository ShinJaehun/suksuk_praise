class CouponTemplate < ApplicationRecord
  has_many :user_coupons, dependent: :restrict_with_exception

  validates :title, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :weight, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  scope :active, -> { where(active: true) }

  def self.weighted_pick
    scope = active
    total = scope.sum(:weight)
    return nil if total <= 0

    ticket = rand(1..total)
    running = 0
    scope.each do |tpl|
      running += tpl.weight
      return tpl if ticket <= running
    end
    nil
  end
end
