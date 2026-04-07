FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    name { "Test User" }
    role { "student" }
    points { 0 }
    default_avatar_index { 1 }

    trait :student do
      role { "student" }
    end

    trait :teacher do
      role { "teacher" }
    end

    trait :admin do
      role { "admin" }
    end
  end
end
