FactoryBot.define do
  factory :coupon_template do
    sequence(:title) { |n| "Coupon #{n}" }
    weight { 100 }
    active { true }
    bucket { "personal" }

    association :created_by, factory: [:user, :teacher]
  end
end
