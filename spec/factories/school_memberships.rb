FactoryBot.define do
  factory :school_membership do
    association :school
    association :user, factory: [:user, :teacher]

    trait :manager do
      role { :manager }
    end
  end
end
