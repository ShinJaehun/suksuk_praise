module ComplimentKings
  class Pick
    Result = Struct.new(:winner, keyword_init: true)

    def self.call(classroom:, basis:, mode:)
      range = case [basis.to_s, mode.to_s]
              when ["daily",  "daily_top"]  then Time.zone.today.all_day
              when ["weekly", "weekly_top"]
                start = Time.zone.now.beginning_of_week(:monday)
                start..start.end_of_week(:monday)
              else
                # 기본: 일간 최다
                Time.zone.today.all_day
              end

      winner = top_receiver_in_range(classroom, range)
      Result.new(winner: winner)
    end

    def self.top_receiver_in_range(classroom, range)
      counts = Compliment.where(classroom: classroom, given_at: range)
                         .group(:receiver_id).count
      return nil if counts.blank?

      max = counts.values.max
      candidate_ids = counts.select { |_, v| v == max }.keys
      classroom.students.where(id: candidate_ids).sample
    end
  end
end