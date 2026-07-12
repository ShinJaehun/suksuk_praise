require "rails_helper"
require "rake"

RSpec.describe "public_holidays:sync" do
  around do |example|
    original_application = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/public_holidays.rake")
    example.run
  ensure
    Rake.application = original_application
  end

  it "syncs the current and next years by default" do
    current_year = Time.zone.today.year
    synced_years = []
    allow(PublicHolidays::SyncYear).to receive(:call) do |year:|
      synced_years << year
      1
    end

    expect { Rake::Task["public_holidays:sync"].invoke }.to output.to_stdout

    expect(synced_years).to eq([current_year, current_year + 1])
  end

  it "syncs only a specified year" do
    allow(PublicHolidays::SyncYear).to receive(:call).and_return(1)

    expect { Rake::Task["public_holidays:sync"].invoke("2026") }.to output.to_stdout

    expect(PublicHolidays::SyncYear).to have_received(:call).with(year: "2026").once
  end

  it "does not swallow service errors" do
    allow(PublicHolidays::SyncYear).to receive(:call).and_raise("sync failed")

    expect { Rake::Task["public_holidays:sync"].invoke("2026") }
      .to raise_error("sync failed")
  end
end
