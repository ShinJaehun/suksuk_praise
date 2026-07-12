require "rails_helper"

RSpec.describe PublicHoliday, type: :model do
  it "stores a valid public holiday" do
    expect(create(:public_holiday)).to be_persisted
  end

  it "requires a date, name, and source" do
    holiday = build(:public_holiday, date: nil, name: nil, source: nil)

    expect(holiday).not_to be_valid
    expect(holiday.errors[:date]).to be_present
    expect(holiday.errors[:name]).to be_present
    expect(holiday.errors[:source]).to be_present
  end

  it "rejects the same date, name, and source combination" do
    existing = create(:public_holiday)
    duplicate = build(
      :public_holiday,
      date: existing.date,
      name: existing.name,
      source: existing.source
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:date]).to be_present
  end

  it "allows a different name or source on the same date" do
    existing = create(:public_holiday)

    different_name = build(:public_holiday, date: existing.date, name: "다른 공휴일")
    different_source = build(:public_holiday, date: existing.date, source: "manual")

    expect(different_name).to be_valid
    expect(different_source).to be_valid
  end
end
