FactoryBot.define do
  factory :classroom do
    sequence(:name) { |n| "Classroom #{n}" }
  end
end
