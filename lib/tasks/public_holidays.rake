namespace :public_holidays do
  desc "Synchronize KASI public holidays for a year or for the current and next years"
  task :sync, [:year] => :environment do |_task, args|
    years = if args[:year].present?
      [args[:year]]
    else
      current_year = Time.zone.today.year
      [current_year, current_year + 1]
    end

    years.each do |year|
      count = PublicHolidays::SyncYear.call(year: year)
      puts "Synced #{year}: #{count} holidays"
    end
  end
end
