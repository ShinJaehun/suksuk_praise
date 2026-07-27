FactoryBot.define do
  factory :student_activity_note do
    association :author, factory: %i[user teacher]
    association :source, factory: :compliment
    body { "학생 활동 관찰 메모" }

    trait :for_coupon_event do
      association :source, factory: :coupon_event
    end
  end
end
