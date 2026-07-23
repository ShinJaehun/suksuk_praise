FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    name { "Test User" }
    role { "student" }
    points { 0 }

    trait :student do
      role { "student" }
      email { nil }
      password { nil }
    end

    trait :teacher do
      role { "teacher" }
      sequence(:email) { |n| "teacher#{n}@example.com" }
      password { "password123" }
    end

    trait :admin do
      role { "admin" }
      sequence(:email) { |n| "admin#{n}@example.com" }
      password { "password123" }
    end
  end
end
