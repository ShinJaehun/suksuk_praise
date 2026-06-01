require "rails_helper"

RSpec.describe "Classroom form settings", type: :request do
  let(:admin) { create(:user, :admin, name: "관리자") }
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
      expect(response.body).to include("교실 이름은 50자 이내로 입력해 주세요.")
    end

    it "shows teacher assignment controls to an admin" do
      teacher
      sign_in admin

      get new_classroom_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("담당 선생님 배정")
      expect(response.body).to include("classroom[teacher_ids][]")
      expect(response.body).to include(teacher.name)
      expect(response.body).to match(/<input(?=[^>]*name="classroom\[teacher_ids\]\[\]")(?=[^>]*value="#{teacher.id}")[^>]*>/)
      expect(response.body).not_to match(/<input(?=[^>]*name="classroom\[teacher_ids\]\[\]")(?=[^>]*value="#{admin.id}")[^>]*>/)
      expect(response.body).not_to include("담당 선생님 저장")
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

    it "rejects a classroom name with more than 50 characters" do
      sign_in teacher

      expect do
        post classrooms_path, params: {
          classroom: {
            name: "가" * 51
          }
        }
      end.not_to change(Classroom, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("50")
    end

    it "rejects an admin classroom without an assigned teacher" do
      sign_in admin

      expect do
        post classrooms_path, params: {
          classroom: {
            name: "담당 교사 없는 교실",
            teacher_ids: [""]
          }
        }
      end.not_to change(Classroom, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("담당 선생님 배정")
    end

    it "creates an admin classroom with only the selected teacher membership" do
      sign_in admin

      post classrooms_path, params: {
        classroom: {
          name: "관리자 생성 교실",
          teacher_ids: [teacher.id.to_s]
        }
      }

      classroom = Classroom.find_by!(name: "관리자 생성 교실")
      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(true)
      expect(classroom.classroom_memberships.teacher.exists?(user: admin)).to eq(false)
    end

  end
end
