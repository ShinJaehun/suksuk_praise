require "rails_helper"

RSpec.describe "Dashboards", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher) }
  let(:student) { create(:user, :student, student_pin: "1234") }

  describe "GET /dashboard" do
    it "redirects guests to sign in" do
      get dashboard_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the admin dashboard summary" do
      sign_in admin

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("한눈에 보기")
      expect(response.body).to include("전체 교실 수")
    end

    it "shows only assigned classrooms to teachers" do
      assigned_classroom = create(:classroom, name: "담당 교실")
      other_classroom = create(:classroom, name: "다른 교실")
      create(:classroom_membership, classroom: assigned_classroom, user: teacher, role: "teacher")
      sign_in teacher

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("한눈에 보기")
      expect(response.body).to include(assigned_classroom.name)
      expect(response.body).not_to include(other_classroom.name)
    end

    it "shows the student's weekday praise counts for the active session classroom" do
      classroom = create(:classroom, name: "학생 교실")
      other_classroom = create(:classroom)
      other_student = create(:user, :student)
      create(:classroom_membership, classroom: classroom, user: student, role: "student")

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        create(:compliment, classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 4, 6, 10, 0, 0))
        create(:compliment, classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 4, 6, 11, 0, 0))
        create(:compliment, classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 4, 8, 10, 0, 0))
        create(:compliment, classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 4, 11, 10, 0, 0))
        create(:compliment, classroom: other_classroom, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))
        create(:compliment, classroom: classroom, receiver: other_student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post classroom_student_login_path(classroom), params: {
          student_id: student.id,
          student_pin: "1234"
        }
        get dashboard_path
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("이번 주 받은 칭찬")
      expect(response.body).to include('data-weekday="월" data-count="2"')
      expect(response.body).to include('data-weekday="화" data-count="0"')
      expect(response.body).to include('data-weekday="수" data-count="1"')
      expect(response.body).to include('data-weekday="목" data-count="0"')
      expect(response.body).to include('data-weekday="금" data-count="0"')
    end

    it "redirects students without an active session classroom membership to student login" do
      sign_in student

      get dashboard_path

      expect(response).to redirect_to(new_student_session_path)
    end
  end
end
