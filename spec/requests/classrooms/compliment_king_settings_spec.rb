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
