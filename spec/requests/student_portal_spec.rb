require "rails_helper"

RSpec.describe "Student portal flow", type: :request do
  describe "student landing and access boundaries" do
    let(:student) { create(:user, :student, password: "password123") }
    let(:teacher) { create(:user, :teacher) }
    let(:classroom) { create(:classroom) }

    before do
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    end

    it "redirects a student to the self page after sign in" do
      post user_session_path, params: {
        user: {
          email: student.email,
          password: "password123"
        }
      }

      expect(response).to redirect_to(user_path(student))
    end

    it "redirects a signed-in student away from classrooms index" do
      sign_in student

      get classrooms_path

      expect(response).to redirect_to(user_path(student))
    end

    it "redirects a signed-in student away from classrooms show" do
      sign_in student

      get classroom_path(classroom)

      expect(response).to redirect_to(user_path(student))
    end

    it "allows a student to view the self page" do
      sign_in student

      get user_path(student)

      expect(response).to have_http_status(:ok)
    end

    it "redirects a teacher from non-nested student show to the classroom-scoped page" do
      sign_in teacher

      get user_path(student)

      expect(response).to redirect_to(classroom_user_path(classroom, student))
    end

    it "allows a teacher to view the classroom-scoped student page" do
      sign_in teacher

      get classroom_user_path(classroom, student)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "student account deletion boundary" do
    let(:student) { create(:user, :student) }
    let(:teacher) { create(:user, :teacher) }
    let(:classroom) { create(:classroom) }

    before do
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    end

    it "rejects self-service student deletion" do
      sign_in student

      expect {
        delete classroom_user_path(classroom, student)
      }.not_to change(User, :count)

      expect(response).to redirect_to(root_path)
    end

    it "allows a classroom teacher to delete a student from the managed page" do
      sign_in teacher

      expect {
        delete classroom_user_path(classroom, student)
      }.to change(User, :count).by(-1)

      expect(response).to redirect_to(classroom_path(classroom))
    end
  end
end
