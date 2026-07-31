FactoryBot.define do
  factory :classroom_membership do
    association :user
    association :classroom
    role { "student" }
    student_number { nil }

    before(:create) do |membership|
      next unless membership.role.to_s == "teacher"
      next unless membership.user&.teacher?
      next if membership.user.school_membership.present?

      membership.user.create_school_membership!(school: membership.classroom.school)
    end
  end
end
