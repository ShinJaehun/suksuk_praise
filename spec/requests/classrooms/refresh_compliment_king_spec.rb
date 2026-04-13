require "rails_helper"

RSpec.describe "Classrooms#refresh_compliment_king", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "POST /classrooms/:id/refresh_compliment_king" do
    let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }

    before do
      sign_in teacher
    end

    it "renders the daily king card for daily period" do
      travel_to Time.zone.local(2026, 4, 7, 12, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post refresh_compliment_king_classroom_path(classroom), params: { period: "daily" }, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 칭찬왕")
        expect(response.body).to include(student.name)
      end
    end

    it "renders the weekly king card for weekly period when enabled" do
      classroom.update!(weekly_compliment_king_enabled: true)
      travel_to Time.zone.local(2026, 4, 8, 12, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post refresh_compliment_king_classroom_path(classroom), params: { period: "weekly" }, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("이번 주 칭찬왕")
        expect(response.body).to include(student.name)
      end
    end

    it "renders the monthly king card for monthly period when enabled" do
      classroom.update!(monthly_compliment_king_enabled: true)
      travel_to Time.zone.local(2026, 4, 20, 12, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post refresh_compliment_king_classroom_path(classroom), params: { period: "monthly" }, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("이번 달 칭찬왕")
        expect(response.body).to include(student.name)
      end
    end

    it "rejects refresh for a disabled period" do
      post refresh_compliment_king_classroom_path(classroom), params: { period: "weekly" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
