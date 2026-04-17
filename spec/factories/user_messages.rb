FactoryBot.define do
  factory :user_message do
    association :classroom
    association :sender, factory: [:user, :teacher]
    association :recipient, factory: [:user, :student]
    body { "안녕, 오늘도 잘하고 있어." }

    trait :reply do
      association :sender, factory: [:user, :student]
      association :recipient, factory: [:user, :teacher]
      association :parent_message, factory: :user_message
    end
  end
end
