FactoryBot.define do
  factory :classroom do
    sequence(:name) { |n| "Classroom #{n}" }
    daily_compliment_king_enabled { true }
    weekly_compliment_king_enabled { false }
    monthly_compliment_king_enabled { false }
  end
end
