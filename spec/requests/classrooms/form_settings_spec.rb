require "rails_helper"

RSpec.describe "Classroom form settings", type: :request do
  let(:teacher) { create(:user, :teacher) }

  describe "GET /classrooms/new" do
    it "shows the shared classroom settings form" do
      sign_in teacher

      get new_classroom_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("교실 기본 정보")
      expect(response.body).to include("칭찬왕 설정")
      expect(response.body).to include("메시지 관리")
      expect(response.body).to include("message_policy")
    end
  end

  describe "POST /classrooms" do
    it "creates a classroom with settings and keeps the creator as a teacher member" do
      sign_in teacher

      post classrooms_path, params: {
        classroom: {
          name: "새 설정 교실",
          daily_compliment_king_enabled: "0",
          weekly_compliment_king_enabled: "1",
          monthly_compliment_king_enabled: "1",
          message_policy: "student_initiated"
        }
      }

      classroom = Classroom.find_by!(name: "새 설정 교실")
      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.daily_compliment_king_enabled?).to eq(false)
      expect(classroom.weekly_compliment_king_enabled?).to eq(true)
      expect(classroom.monthly_compliment_king_enabled?).to eq(true)
      expect(classroom.message_policy).to eq("student_initiated")
      expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(true)
    end
  end
end
