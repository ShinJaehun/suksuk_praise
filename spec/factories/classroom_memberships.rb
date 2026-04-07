FactoryBot.define do
  factory :classroom_membership do
    association :user
    association :classroom
    role { "student" }
  end
end
