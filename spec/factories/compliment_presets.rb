FactoryBot.define do
  factory :compliment_preset do
    association :user, factory: [:user, :teacher]
    sequence(:title) { |n| "맞춤 칭찬 #{n}" }
    sequence(:position) { |n| n }
    active { true }
  end
end
