require "rails_helper"

RSpec.describe "Classroom form settings", type: :request do
  let(:admin) { create(:user, :admin, name: "관리자") }
  let(:teacher) { create(:user, :teacher) }
  let(:school) { create(:school) }
  let(:manager) { create(:user, :teacher) }

  describe "GET /classrooms/new" do
    it "shows the shared classroom settings form" do
      sign_in admin

      get new_classroom_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("교실 기본 정보")
      expect(response.body).to include("칭찬왕 설정")
      expect(response.body).to include("메시지 관리")
      expect(response.body).to include("message_policy")
      expect(response.body).to include("교실 이름은 50자 이내로 입력해 주세요.")
    end

    it "hides operation settings from a manager" do
      create(:school_membership, :manager, school: school, user: manager)
      member_teacher = create(:school_membership, school: school, user: create(:user, :teacher, name: "같은 학교 교사")).user
      other_school_teacher = create(:school_membership, school: create(:school), user: create(:user, :teacher, name: "다른 학교 교사")).user
      sign_in manager

      get new_classroom_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("교실 기본 정보")
      expect(response.body).to include("담당 선생님 배정")
      expect(response.body).to include("classroom[teacher_ids][]")
      expect(response.body).to include(manager.name)
      expect(response.body).to include(member_teacher.name)
      expect(response.body).not_to include(other_school_teacher.name)
      expect(response.body).not_to include("칭찬왕 설정")
      expect(response.body).not_to include("메시지 관리")
      expect(response.body).not_to include("message_policy")
    end

    it "shows assignment-after-create guidance to an admin" do
      teacher
      sign_in admin

      get new_classroom_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("담당 선생님 배정")
      expect(response.body).to include("교실을 만든 뒤 관리 화면에서 담당 선생님을 배정해 주세요.")
      expect(response.body).not_to include("classroom[teacher_ids][]")
      expect(response.body).not_to include(teacher.name)
      expect(response.body).not_to include("담당 선생님 저장")
    end
  end

  describe "POST /classrooms" do
    it "creates an admin classroom with settings and no teacher assignment" do
      sign_in admin

      post classrooms_path, params: {
        classroom: {
          name: "새 설정 교실",
          school_id: school.id,
          grade: 4,
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
      expect(classroom.classroom_memberships.teacher).to be_empty
    end

    it "rejects a classroom name with more than 50 characters" do
      create(:school_membership, :manager, school: school, user: manager)
      sign_in manager

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

    it "rejects teacher assignment params on admin classroom creation" do
      sign_in admin

      expect do
        post classrooms_path, params: {
          classroom: {
            name: "담당 교사 없는 교실",
            teacher_ids: [teacher.id.to_s]
          }
        }
      end.not_to change(Classroom, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("교실을 만든 뒤 관리 화면에서 담당 선생님을 배정해 주세요.")
    end

    it "creates an admin classroom without a selected teacher membership" do
      sign_in admin

      post classrooms_path, params: {
        classroom: {
          name: "관리자 생성 교실",
          school_id: school.id,
          grade: 4
        }
      }

      classroom = Classroom.find_by!(name: "관리자 생성 교실")
      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(false)
      expect(classroom.classroom_memberships.teacher.exists?(user: admin)).to eq(false)
    end

  end

  describe "GET /classrooms/:id/edit" do
    it "shows only basic fields and teacher assignment controls to a manager" do
      create(:school_membership, :manager, school: school, user: manager)
      classroom = create(:classroom, school: school)
      sign_in manager

      get edit_classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("교실 기본 정보")
      expect(response.body).to include("담당 선생님 배정")
      expect(response.body).to include("classroom[name]")
      expect(response.body).to include("classroom[grade]")
      expect(response.body).not_to include("classroom[school_id]")
      expect(response.body).not_to include("칭찬왕 설정")
      expect(response.body).not_to include("메시지 관리")
      expect(response.body).not_to include("message_policy")
    end

    it "shows operation settings to a manager assigned as the classroom teacher" do
      create(:school_membership, :manager, school: school, user: manager)
      classroom = create(:classroom, school: school)
      create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
      sign_in manager

      get edit_classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("교실 기본 정보")
      expect(response.body).to include("담당 선생님 배정")
      expect(response.body).to include("칭찬왕 설정")
      expect(response.body).to include("메시지 관리")
      expect(response.body).to include("message_policy")
    end
  end
end
