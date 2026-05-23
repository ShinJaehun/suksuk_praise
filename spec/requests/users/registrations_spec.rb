require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  let(:student) { create(:user, :student, password: "password123") }
  let(:teacher) { create(:user, :teacher, password: "password123") }
  let(:admin) { create(:user, :admin, password: "password123") }

  describe "GET /users/edit" do
    it "blocks student access" do
      sign_in student

      get edit_user_registration_path

      expect(response).to redirect_to(user_path(student))
    end

    it "allows teacher access" do
      sign_in teacher

      get edit_user_registration_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /users" do
    it "blocks student self-service profile updates" do
      sign_in student

      patch user_registration_path, params: {
        user: {
          name: "바뀐 학생 이름",
          email: student.email
        }
      }

      expect(response).to redirect_to(user_path(student))
      expect(student.reload.name).not_to eq("바뀐 학생 이름")
    end

    it "updates teacher profile attributes without requiring the current password" do
      sign_in teacher

      patch user_registration_path, params: {
        user: {
          name: "바뀐 교사 이름",
          email: teacher.email
        }
      }

      expect(response).to redirect_to(user_path(teacher))
      expect(teacher.reload.name).to eq("바뀐 교사 이름")
    end

    it "updates admin profile attributes without requiring the current password" do
      sign_in admin

      patch user_registration_path, params: {
        user: {
          name: "바뀐 관리자 이름",
          email: admin.email
        }
      }

      expect(response).to redirect_to(user_path(admin))
      expect(admin.reload.name).to eq("바뀐 관리자 이름")
    end
  end

  describe "GET /account/password/edit" do
    it "blocks student access" do
      sign_in student

      get edit_account_password_path

      expect(response).to redirect_to(user_path(student))
    end

    it "allows teacher access" do
      sign_in teacher

      get edit_account_password_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /account/password" do
    let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }

    it "blocks student password changes" do
      sign_in student

      patch account_password_path,
            params: {
              user: {
                current_password: "password123",
                password: "newpassword123",
                password_confirmation: "newpassword123"
              }
            },
            headers: turbo_headers

      expect(response).to redirect_to(user_path(student))
      expect(student.reload.valid_password?("password123")).to eq(true)
    end

    it "rejects teacher password changes without the current password" do
      sign_in teacher

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
      expect(teacher.reload.valid_password?("password123")).to eq(true)
    end

    it "updates the teacher password when the current password matches" do
      sign_in teacher

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
      expect(teacher.reload.valid_password?("newpassword123")).to eq(true)
    end
  end
end
