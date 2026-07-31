namespace :school_structure do
  desc "Audit school and classroom data integrity without modifying records"
  task audit: :environment do
    limit = ENV.fetch("LIMIT", SchoolStructure::IntegrityAudit::DEFAULT_SAMPLE_LIMIT)
    result = SchoolStructure::IntegrityAudit.call(sample_limit: limit)

    puts "School structure integrity audit"
    puts

    SchoolStructure::IntegrityAudit::ISSUE_LABELS.each do |type, label|
      puts "#{label}: #{result.count_for(type)}"
      result.samples_for(type).each { |sample| puts "  sample: #{sample.inspect}" }
    end

    puts
    puts "Result: #{result.clean? ? 'CLEAN' : 'ISSUES FOUND'}"

    abort("School structure integrity issues found") unless result.clean?
  end
end
