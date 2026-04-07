FactoryBot.define do
  factory :user_coupon do
    association :user, factory: [:user, :student]
    association :classroom
    association :coupon_template

    status { :issued }
    issued_at { Time.zone.local(2026, 4, 7, 10, 0, 0) }
    issuance_basis { "daily" }
    period_start_on { issued_at.to_date }

    before(:create) do |user_coupon|
      next if ClassroomMembership.exists?(
        user: user_coupon.user,
        classroom: user_coupon.classroom
      )

      create(:classroom_membership, user: user_coupon.user, classroom: user_coupon.classroom, role: "student")
    end
  end
end
