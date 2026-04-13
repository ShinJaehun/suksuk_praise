require "rails_helper"

RSpec.describe "Classrooms compliment kings", type: :request do
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
  end
end
