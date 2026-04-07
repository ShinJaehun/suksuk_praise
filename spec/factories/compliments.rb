FactoryBot.define do
  factory :compliment do
    association :giver, factory: [:user, :teacher]
    association :receiver, factory: [:user, :student]
    association :classroom
    given_at { Time.zone.local(2026, 4, 7, 10, 0, 0) }
  end
end
