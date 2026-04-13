require "rails_helper"

RSpec.describe CouponDraw::Issue, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    it "requires a target user id" do
      teacher = create(:user, :teacher)
      classroom = create(:classroom)

      expect {
        described_class.call(classroom: classroom, basis: "daily", mode: "daily_top", issued_by: teacher)
      }.to raise_error(CouponDraw::Issue::MissingUserIdError)
    end

    it "rejects a daily top target who is not today's compliment king" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      king = create(:user, :student)
      classroom = create(:classroom)
      now = Time.zone.local(2026, 4, 7, 10, 0, 0)

      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:classroom_membership, user: king, classroom: classroom, role: "student")
      create(:compliment, classroom: classroom, giver: teacher, receiver: king, given_at: now)

      travel_to now do
        expect {
          described_class.call(
            classroom: classroom,
            basis: "daily",
            mode: "daily_top",
            issued_by: teacher,
            target_user_id: student.id
          )
        }.to raise_error(CouponDraw::Issue::NotComplimentKingToday)
      end
    end

    it "prevents duplicate daily issuance for the same basis tag and period" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher)
      now = Time.zone.local(2026, 4, 7, 10, 0, 0)

      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(
        :user_coupon,
        user: student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher,
        issuance_basis: "daily",
        basis_tag: "default",
        period_start_on: now.to_date
      )

      travel_to now do
        expect {
          described_class.call(
            classroom: classroom,
            basis: "manual",
            mode: "default",
            issued_by: teacher,
            target_user_id: student.id
          )
        }.not_to raise_error

        expect {
          described_class.call(
            classroom: classroom,
            basis: "daily",
            mode: "default",
            issued_by: teacher,
            target_user_id: student.id
          )
        }.to raise_error(CouponDraw::Issue::DuplicatePeriodError)
      end
    end

    it "allows a weekly top winner to receive a weekly coupon once per week" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher, active: true, weight: 100)
      now = Time.zone.local(2026, 4, 8, 10, 0, 0)

      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 9, 0, 0))
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 8, 9, 0, 0))

      travel_to now do
        coupon = described_class.call(
          classroom: classroom,
          basis: "weekly",
          mode: "weekly_top",
          issued_by: teacher,
          target_user_id: student.id
        )

        expect(coupon).to be_persisted
        expect(coupon.coupon_template).to eq(template)
        expect(coupon.issuance_basis).to eq("weekly")
        expect(coupon.period_start_on).to eq(Date.new(2026, 4, 6))
      end
    end

    it "rejects duplicate weekly issuance in the same week" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher)
      now = Time.zone.local(2026, 4, 8, 10, 0, 0)

      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(
        :user_coupon,
        user: student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher,
        issuance_basis: "weekly",
        basis_tag: "weekly_top",
        period_start_on: Date.new(2026, 4, 6)
      )

      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 9, 0, 0))

      travel_to now do
        expect {
          described_class.call(
            classroom: classroom,
            basis: "weekly",
            mode: "weekly_top",
            issued_by: teacher,
            target_user_id: student.id
          )
        }.to raise_error(CouponDraw::Issue::DuplicatePeriodError)
      end
    end

    it "allows a monthly top winner to receive a monthly coupon once per month" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher, active: true, weight: 100)
      now = Time.zone.local(2026, 4, 20, 10, 0, 0)

      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 2, 9, 0, 0))
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 20, 9, 0, 0))

      travel_to now do
        coupon = described_class.call(
          classroom: classroom,
          basis: "monthly",
          mode: "monthly_top",
          issued_by: teacher,
          target_user_id: student.id
        )

        expect(coupon).to be_persisted
        expect(coupon.coupon_template).to eq(template)
        expect(coupon.issuance_basis).to eq("monthly")
        expect(coupon.period_start_on).to eq(Date.new(2026, 4, 1))
      end
    end

    it "rejects duplicate monthly issuance in the same month" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher)
      now = Time.zone.local(2026, 4, 20, 10, 0, 0)

      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(
        :user_coupon,
        user: student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher,
        issuance_basis: "monthly",
        basis_tag: "monthly_top",
        period_start_on: Date.new(2026, 4, 1)
      )

      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: now)

      travel_to now do
        expect {
          described_class.call(
            classroom: classroom,
            basis: "monthly",
            mode: "monthly_top",
            issued_by: teacher,
            target_user_id: student.id
          )
        }.to raise_error(CouponDraw::Issue::DuplicatePeriodError)
      end
    end

    it "rejects issuance when the teacher has no active personal template" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)

      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:coupon_template, created_by: teacher, active: false, weight: 0)

      expect {
        described_class.call(
          classroom: classroom,
          basis: "manual",
          mode: "default",
          issued_by: teacher,
          target_user_id: student.id
        )
      }.to raise_error(CouponDraw::Issue::NoActiveTemplateError)
    end

    it "creates a coupon and an issued event" do
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      classroom = create(:classroom)
      template = create(:coupon_template, created_by: teacher, active: true, weight: 100)
      now = Time.zone.local(2026, 4, 7, 10, 0, 0)

      create(:classroom_membership, user: student, classroom: classroom, role: "student")

      travel_to now do
        coupon = described_class.call(
          classroom: classroom,
          basis: "manual",
          mode: "default",
          issued_by: teacher,
          target_user_id: student.id
        )

        expect(coupon).to be_persisted
        expect(coupon.coupon_template).to eq(template)
        expect(CouponEvent.last).to have_attributes(action: "issued", user_coupon: coupon, actor: teacher)
      end
    end
  end
end
