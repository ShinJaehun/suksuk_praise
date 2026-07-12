require "rails_helper"

RSpec.describe SchoolClosure, type: :model do
  it "stores a valid date range and exposes its school association" do
    school = create(:school)
    closure = create(
      :school_closure,
      school: school,
      name: "여름방학",
      starts_on: Date.new(2026, 7, 20),
      ends_on: Date.new(2026, 8, 14)
    )

    expect(closure).to be_persisted
    expect(closure.school).to eq(school)
    expect(school.school_closures).to contain_exactly(closure)
  end

  it "allows a one-day closure" do
    date = Date.new(2026, 7, 15)

    expect(build(:school_closure, starts_on: date, ends_on: date)).to be_valid
  end

  it "requires a name, start date, and end date" do
    closure = build(:school_closure, name: nil, starts_on: nil, ends_on: nil)

    expect(closure).not_to be_valid
    expect(closure.errors[:name]).to be_present
    expect(closure.errors[:starts_on]).to be_present
    expect(closure.errors[:ends_on]).to be_present
  end

  it "rejects an end date before the start date" do
    closure = build(
      :school_closure,
      starts_on: Date.new(2026, 7, 15),
      ends_on: Date.new(2026, 7, 14)
    )

    expect(closure).not_to be_valid
    expect(closure.errors[:ends_on]).to be_present
  end

  it "allows overlapping closures for the same school" do
    school = create(:school)
    create(
      :school_closure,
      school: school,
      starts_on: Date.new(2026, 7, 13),
      ends_on: Date.new(2026, 7, 17)
    )

    overlapping = build(
      :school_closure,
      school: school,
      starts_on: Date.new(2026, 7, 15),
      ends_on: Date.new(2026, 7, 20)
    )

    expect(overlapping).to be_valid
  end

  it "keeps closures independent between schools" do
    first = create(:school_closure)
    second = create(
      :school_closure,
      school: create(:school),
      starts_on: first.starts_on,
      ends_on: first.ends_on
    )

    expect(first.school).not_to eq(second.school)
    expect(first.school.school_closures).to contain_exactly(first)
    expect(second.school.school_closures).to contain_exactly(second)
  end

  it "prevents its school from being deleted" do
    closure = create(:school_closure)

    expect { closure.school.destroy }.not_to change(School, :count)
    expect(closure.school).not_to be_destroyed
    expect(closure).to be_persisted
  end
end
