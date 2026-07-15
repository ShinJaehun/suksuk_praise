FactoryBot.define do
  factory :coupon_event do
    action { "issued" }
    association :actor, factory: [:user, :teacher]
    association :user_coupon, factory: [:user_coupon, :with_classroom_membership]
    classroom { user_coupon.classroom }
    coupon_template { user_coupon.coupon_template }
    metadata { {} }
  end
end
