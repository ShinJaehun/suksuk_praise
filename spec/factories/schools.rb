FactoryBot.define do
  factory :school do
    sequence(:name) { |n| "School #{n}" }
  end
end
