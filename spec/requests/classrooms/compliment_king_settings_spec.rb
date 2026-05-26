require "rails_helper"

RSpec.describe "Classroom compliment king settings", type: :request do
  describe "PATCH /classrooms/:id" do
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }

    it "allows a classroom teacher to update weekly/monthly toggles" do
      sign_in teacher

      patch classroom_path(classroom), params: {
        classroom: {
          name: classroom.name,
          weekly_compliment_king_enabled: "1",
          monthly_compliment_king_enabled: "1"
        }
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.reload.weekly_compliment_king_enabled?).to eq(true)
      expect(classroom.monthly_compliment_king_enabled?).to eq(true)
      expect(classroom.daily_compliment_king_enabled?).to eq(true)
    end

    it "allows a classroom teacher to update message policy" do
      sign_in teacher

      patch classroom_path(classroom), params: {
        classroom: {
          name: classroom.name,
          message_policy: "student_initiated"
        }
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.reload.message_policy).to eq("student_initiated")
    end

    it "shows the message management setting on edit" do
      sign_in teacher

      get edit_classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("메시지 관리")
      expect(response.body).to include("message_policy")
      expect(response.body).to include("메시지 사용 안 함")
      expect(response.body).to include("답장만 허용")
      expect(response.body).to include("학생 먼저 메시지 허용")
    end

    it "rejects a student" do
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      sign_in student

      patch classroom_path(classroom),
        params: { classroom: { weekly_compliment_king_enabled: "1" } },
        as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq("ok" => false, "error" => "not_authorized")
      expect(classroom.reload.weekly_compliment_king_enabled?).to eq(false)
    end
  end
end
