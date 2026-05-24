FactoryBot.define do
  factory :coupon_use_request do
    association :user_coupon
    classroom { user_coupon.classroom }
    student { user_coupon.user }
    requested_by { student }
    status { :pending }
    requested_at { Time.zone.local(2026, 4, 7, 10, 5, 0) }
  end
end
