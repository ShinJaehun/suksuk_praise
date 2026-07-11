FactoryBot.define do
  factory :school_membership do
    association :school
    association :user, factory: [:user, :teacher]
  end
end
