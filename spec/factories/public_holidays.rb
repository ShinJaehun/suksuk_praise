FactoryBot.define do
  factory :public_holiday do
    sequence(:date) { |number| Date.new(2026, 1, 1) + number.days }
    name { '광복절 대체공휴일' }
    source { 'official_api' }
  end
end
