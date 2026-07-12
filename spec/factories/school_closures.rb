FactoryBot.define do
  factory :school_closure do
    association :school
    name { "학교 휴무" }
    starts_on { Date.new(2026, 7, 13) }
    ends_on { Date.new(2026, 7, 14) }
  end
end
