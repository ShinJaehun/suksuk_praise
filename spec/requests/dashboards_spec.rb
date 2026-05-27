require "rails_helper"

RSpec.describe "Dashboards", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher) }
  let(:student) { create(:user, :student) }

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

    it "redirects students to their canonical student page" do
      sign_in student

      get dashboard_path

      expect(response).to redirect_to(user_path(student))
    end
  end
end
