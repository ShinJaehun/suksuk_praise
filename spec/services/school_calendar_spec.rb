require "rails_helper"

RSpec.describe SchoolCalendar do
  let(:school) { create(:school) }
  let(:calendar) { described_class.new(school) }

  describe "#school_day?" do
    it "treats a weekday as a school day and weekends as closed" do
      expect(calendar.school_day?(Date.new(2026, 7, 16))).to eq(true)
      expect(calendar.school_day?(Date.new(2026, 7, 18))).to eq(false)
      expect(calendar.school_day?(Date.new(2026, 7, 19))).to eq(false)
    end

    it "treats one-day and multi-day school closures as closed" do
      create(
        :school_closure,
        school: school,
        starts_on: Date.new(2026, 7, 15),
        ends_on: Date.new(2026, 7, 15)
      )
      create(
        :school_closure,
        school: school,
        starts_on: Date.new(2026, 7, 20),
        ends_on: Date.new(2026, 7, 24)
      )

      expect(calendar.school_day?(Date.new(2026, 7, 15))).to eq(false)
      expect(calendar.school_day?(Date.new(2026, 7, 22))).to eq(false)
      expect(calendar.school_day?(Date.new(2026, 7, 27))).to eq(true)
    end

    it "ignores closures belonging to another school" do
      create(
        :school_closure,
        school: create(:school),
        starts_on: Date.new(2026, 7, 16),
        ends_on: Date.new(2026, 7, 16)
      )

      expect(calendar.school_day?(Date.new(2026, 7, 16))).to eq(true)
    end

    it "treats a weekday public holiday as closed without affecting other dates" do
      create(:public_holiday, date: Date.new(2026, 7, 16))

      expect(calendar.school_day?(Date.new(2026, 7, 16))).to eq(false)
      expect(calendar.school_day?(Date.new(2026, 7, 17))).to eq(true)
    end

    it "applies public holidays to every school" do
      date = Date.new(2026, 7, 16)
      create(:public_holiday, date: date)
      other_calendar = described_class.new(create(:school))

      expect(calendar.school_day?(date)).to eq(false)
      expect(other_calendar.school_day?(date)).to eq(false)
    end
  end

  describe "#last_school_day_of_week" do
    it "returns Friday when Friday is a school day" do
      expect(calendar.last_school_day_of_week(Date.new(2026, 7, 15))).to eq(Date.new(2026, 7, 17))
    end

    it "returns Thursday when Friday is a closure" do
      create(
        :school_closure,
        school: school,
        starts_on: Date.new(2026, 7, 17),
        ends_on: Date.new(2026, 7, 17)
      )

      expect(calendar.last_school_day_of_week(Date.new(2026, 7, 15))).to eq(Date.new(2026, 7, 16))
    end

    it "returns nil when the entire week is closed" do
      create(
        :school_closure,
        school: school,
        starts_on: Date.new(2026, 7, 13),
        ends_on: Date.new(2026, 7, 19)
      )

      expect(calendar.last_school_day_of_week(Date.new(2026, 7, 15))).to be_nil
    end

    it "returns Thursday when Friday is a public holiday" do
      create(:public_holiday, date: Date.new(2026, 7, 17))

      expect(calendar.last_school_day_of_week(Date.new(2026, 7, 15))).to eq(Date.new(2026, 7, 16))
    end

    it "combines school closures and public holidays" do
      create(:public_holiday, date: Date.new(2026, 7, 16))
      create(
        :school_closure,
        school: school,
        starts_on: Date.new(2026, 7, 17),
        ends_on: Date.new(2026, 7, 17)
      )

      expect(calendar.last_school_day_of_week(Date.new(2026, 7, 15))).to eq(Date.new(2026, 7, 15))
    end
  end

  describe "#last_school_day_of_month" do
    it "returns month-end when month-end is a school day" do
      expect(calendar.last_school_day_of_month(Date.new(2026, 7, 10))).to eq(Date.new(2026, 7, 31))
    end

    it "returns the previous school day when month-end is a weekend" do
      expect(calendar.last_school_day_of_month(Date.new(2026, 5, 10))).to eq(Date.new(2026, 5, 29))
    end

    it "returns the previous school day when month-end is closed" do
      create(
        :school_closure,
        school: school,
        starts_on: Date.new(2026, 7, 31),
        ends_on: Date.new(2026, 7, 31)
      )

      expect(calendar.last_school_day_of_month(Date.new(2026, 7, 10))).to eq(Date.new(2026, 7, 30))
    end

    it "returns the previous school day when a closure continues through month-end" do
      create(
        :school_closure,
        school: school,
        starts_on: Date.new(2026, 7, 27),
        ends_on: Date.new(2026, 7, 31)
      )

      expect(calendar.last_school_day_of_month(Date.new(2026, 7, 10))).to eq(Date.new(2026, 7, 24))
    end

    it "returns nil when the entire month is closed" do
      create(
        :school_closure,
        school: school,
        starts_on: Date.new(2026, 7, 1),
        ends_on: Date.new(2026, 7, 31)
      )

      expect(calendar.last_school_day_of_month(Date.new(2026, 7, 10))).to be_nil
    end

    it "returns the previous school day when month-end is a public holiday" do
      create(:public_holiday, date: Date.new(2026, 7, 31))

      expect(calendar.last_school_day_of_month(Date.new(2026, 7, 10))).to eq(Date.new(2026, 7, 30))
    end
  end
end
