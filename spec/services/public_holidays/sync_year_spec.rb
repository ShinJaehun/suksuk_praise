require "rails_helper"

RSpec.describe PublicHolidays::SyncYear do
  let(:source) { PublicHolidays::KasiClient::SOURCE }
  let(:first_holiday) do
    { date: Date.new(2026, 1, 1), name: "1월1일", source: source }
  end
  let(:second_holiday) do
    { date: Date.new(2026, 3, 1), name: "삼일절", source: source }
  end

  def fake_client(results)
    instance_double(PublicHolidays::KasiClient, fetch_year: results)
  end

  it "stores the requested year's KASI holidays" do
    count = described_class.call(year: 2026, client: fake_client([first_holiday, second_holiday]))

    expect(count).to eq(2)
    expect(PublicHoliday.where(source: source).pluck(:date, :name)).to contain_exactly(
      [first_holiday[:date], first_holiday[:name]],
      [second_holiday[:date], second_holiday[:name]]
    )
  end

  it "replaces prior data without duplicates and removes missing items" do
    create(:public_holiday, **first_holiday)
    create(:public_holiday, **second_holiday)

    described_class.call(year: 2026, client: fake_client([first_holiday, first_holiday]))

    expect(PublicHoliday.where(source: source).pluck(:date, :name)).to eq([
      [first_holiday[:date], first_holiday[:name]]
    ])
  end

  it "preserves other sources and years" do
    manual = create(:public_holiday, date: Date.new(2026, 5, 5), source: "manual")
    other_year = create(:public_holiday, date: Date.new(2027, 1, 1), source: source)

    described_class.call(year: 2026, client: fake_client([first_holiday]))

    expect(manual.reload).to be_persisted
    expect(other_year.reload).to be_persisted
  end

  it "preserves existing data when the client fails or returns no holidays" do
    existing = create(:public_holiday, **first_holiday)
    failing_client = instance_double(PublicHolidays::KasiClient)
    allow(failing_client).to receive(:fetch_year).and_raise(PublicHolidays::KasiClient::ResponseError)

    expect do
      described_class.call(year: 2026, client: failing_client)
    end.to raise_error(PublicHolidays::KasiClient::ResponseError)
    expect(existing.reload).to be_persisted

    expect do
      described_class.call(year: 2026, client: fake_client([]))
    end.to raise_error(described_class::EmptyResultError)
    expect(existing.reload).to be_persisted
  end

  it "rolls back deletion when insertion fails" do
    existing = create(:public_holiday, **first_holiday)
    invalid = { date: Date.new(2026, 2, 1), name: nil, source: source }

    expect do
      described_class.call(year: 2026, client: fake_client([invalid]))
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(existing.reload).to be_persisted
  end

  it "uses the injected client for the requested year" do
    client = fake_client([first_holiday])

    described_class.call(year: 2026, client: client)

    expect(client).to have_received(:fetch_year).with(2026)
  end

  it "rejects a year that is not a four-digit integer" do
    expect do
      described_class.call(year: "invalid", client: fake_client([first_holiday]))
    end.to raise_error(described_class::InvalidYearError)
  end
end
