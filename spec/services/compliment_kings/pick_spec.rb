require "rails_helper"

RSpec.describe ComplimentKings::Pick, type: :service do
  describe ".call" do
    it "keeps daily behavior for today's compliments" do
      classroom = create(:classroom)
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 11, 0, 0))

      result = described_class.call(classroom: classroom, period: "daily", now: Time.zone.local(2026, 4, 7, 12, 0, 0))

      expect(result.period).to eq("daily")
      expect(result.winners).to eq([student])
      expect(result.compliment_count).to eq(2)
    end

    it "uses monday-based range for weekly" do
      classroom = create(:classroom)
      teacher = create(:user, :teacher)
      weekly_winner = create(:user, :student)
      outsider = create(:user, :student)
      create(:classroom_membership, user: weekly_winner, classroom: classroom, role: "student")
      create(:classroom_membership, user: outsider, classroom: classroom, role: "student")

      create(:compliment, classroom: classroom, giver: teacher, receiver: weekly_winner, given_at: Time.zone.local(2026, 4, 6, 10, 0, 0))
      create(:compliment, classroom: classroom, giver: teacher, receiver: weekly_winner, given_at: Time.zone.local(2026, 4, 8, 10, 0, 0))
      create(:compliment, classroom: classroom, giver: teacher, receiver: outsider, given_at: Time.zone.local(2026, 4, 5, 10, 0, 0))

      result = described_class.call(classroom: classroom, period: "weekly", now: Time.zone.local(2026, 4, 8, 12, 0, 0))

      expect(result.winners).to eq([weekly_winner])
      expect(result.compliment_count).to eq(2)
    end

    it "uses the current month range for monthly" do
      classroom = create(:classroom)
      teacher = create(:user, :teacher)
      monthly_winner = create(:user, :student)
      other_student = create(:user, :student)
      create(:classroom_membership, user: monthly_winner, classroom: classroom, role: "student")
      create(:classroom_membership, user: other_student, classroom: classroom, role: "student")

      create(:compliment, classroom: classroom, giver: teacher, receiver: monthly_winner, given_at: Time.zone.local(2026, 4, 2, 10, 0, 0))
      create(:compliment, classroom: classroom, giver: teacher, receiver: monthly_winner, given_at: Time.zone.local(2026, 4, 20, 10, 0, 0))
      create(:compliment, classroom: classroom, giver: teacher, receiver: other_student, given_at: Time.zone.local(2026, 3, 31, 10, 0, 0))

      result = described_class.call(classroom: classroom, period: "monthly", now: Time.zone.local(2026, 4, 20, 12, 0, 0))

      expect(result.winners).to eq([monthly_winner])
      expect(result.compliment_count).to eq(2)
    end

    it "returns tied winners and the shared compliment count" do
      classroom = create(:classroom)
      teacher = create(:user, :teacher)
      first = create(:user, :student)
      second = create(:user, :student)
      create(:classroom_membership, user: first, classroom: classroom, role: "student")
      create(:classroom_membership, user: second, classroom: classroom, role: "student")

      create(:compliment, classroom: classroom, giver: teacher, receiver: first, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))
      create(:compliment, classroom: classroom, giver: teacher, receiver: second, given_at: Time.zone.local(2026, 4, 7, 11, 0, 0))

      result = described_class.call(classroom: classroom, period: "daily", now: Time.zone.local(2026, 4, 7, 12, 0, 0))

      expect(result.winners).to eq([first, second])
      expect(result.compliment_count).to eq(1)
    end
  end
end
