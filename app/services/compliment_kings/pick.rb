module ComplimentKings
  class Pick
    Result = Struct.new(:period, :winners, :compliment_count, keyword_init: true)

    def self.call(classroom:, period:, now: Time.zone.now)
      range = range_for(period, now: now)
      counts = Compliment.where(classroom: classroom, given_at: range).group(:receiver_id).count

      return Result.new(period: period.to_s, winners: [], compliment_count: 0) if counts.blank?

      max = counts.values.max
      candidate_ids = counts.select { |_, value| value == max }.keys
      winners = classroom.students.where(id: candidate_ids).order(:id).to_a

      Result.new(
        period: period.to_s,
        winners: winners,
        compliment_count: max
      )
    end

    def self.range_for(period, now: Time.zone.now)
      case period.to_s
      when "daily"
        now.to_date.all_day
      when "weekly"
        start_date = now.beginning_of_week(:monday)
        start_date..start_date.end_of_week(:monday)
      when "monthly"
        start_date = now.beginning_of_month
        start_date..start_date.end_of_month
      else
        raise ArgumentError, "unsupported period: #{period}"
      end
    end
  end
end
