require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  let(:student) { create(:user, :student, password: "password123") }

  before do
    sign_in student
  end

  describe "PATCH /users" do
    it "updates profile attributes without requiring the current password" do
      patch user_registration_path, params: {
        user: {
          name: "바뀐 학생 이름",
          email: student.email
        }
      }

      expect(response).to redirect_to(user_path(student))
      expect(student.reload.name).to eq("바뀐 학생 이름")
    end
  end

  describe "PATCH /account/password" do
    let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }

    it "rejects password changes without the current password" do
      patch account_password_path,
            params: {
              user: {
                current_password: "",
                password: "newpassword123",
                password_confirmation: "newpassword123"
              }
            },
            headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(student.reload.valid_password?("password123")).to eq(true)
    end

    it "updates the password when the current password matches" do
      patch account_password_path,
            params: {
              user: {
                current_password: "password123",
                password: "newpassword123",
                password_confirmation: "newpassword123"
              }
            },
            headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(student.reload.valid_password?("newpassword123")).to eq(true)
    end
  end
end
