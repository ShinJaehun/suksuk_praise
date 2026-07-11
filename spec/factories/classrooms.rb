FactoryBot.define do
  factory :classroom do
    association :school
    sequence(:name) { |n| "Classroom #{n}" }
    grade { 4 }
    daily_compliment_king_enabled { true }
    weekly_compliment_king_enabled { false }
    monthly_compliment_king_enabled { false }
  end
end
