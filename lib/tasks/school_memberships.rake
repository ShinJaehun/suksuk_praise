namespace :school_memberships do
  desc "Backfill school memberships from classroom teacher assignments"
  task backfill: :environment do
    result = SchoolMemberships::Backfill.call
    puts "created=#{result.created} skipped=#{result.skipped} conflicts=#{result.conflicts}"
  end
end
