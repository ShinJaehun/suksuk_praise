class CouponEvent < ApplicationRecord
  belongs_to :actor, class_name: 'User'
  belongs_to :user_coupon
  belongs_to :classroom
  belongs_to :coupon_template

  validates :action, presence: true, inclusion: { in: %w[issued used] }
end
