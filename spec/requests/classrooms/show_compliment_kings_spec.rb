require "rails_helper"

RSpec.describe "Classrooms compliment kings", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "GET /classrooms/:id" do
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }

    before do
      sign_in teacher
    end

    it "shows only enabled period buttons on initial load" do
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

      get classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("오늘의 칭찬왕")
      expect(response.body).to include("href=\"#{classroom_student_path(classroom, student)}\"")
      expect(response.body).not_to include("이번 주 칭찬왕")
      expect(response.body).not_to include("이번 달 칭찬왕")
    end

    it "shows the weekly king button only when weekly is enabled" do
      classroom.update!(weekly_compliment_king_enabled: true)
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

      get classroom_path(classroom)

      expect(response.body).to include("오늘의 칭찬왕")
      expect(response.body).to include("이번 주 칭찬왕")
      expect(response.body).not_to include("이번 달 칭찬왕")
    end

    it "shows the monthly king button only when monthly is enabled" do
      classroom.update!(monthly_compliment_king_enabled: true)
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

      get classroom_path(classroom)

      expect(response.body).to include("오늘의 칭찬왕")
      expect(response.body).to include("이번 달 칭찬왕")
      expect(response.body).not_to include("이번 주 칭찬왕")
    end

    it "shows today's compliment count on student cards instead of total points" do
      student.update!(points: 9)

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: 1.day.ago)
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.current)

        get classroom_path(classroom)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("오늘 칭찬")
      expect(response.body).not_to include("칭찬(포인트)")
      expect(response.body).to match(/오늘 칭찬.*text-2xl[^>]*>1<\/div>/m)
    end
  end
end
