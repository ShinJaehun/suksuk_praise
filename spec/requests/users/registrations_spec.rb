require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  let(:student) { create(:user, :student) }
  let(:teacher) { create(:user, :teacher, password: "password123") }
  let(:admin) { create(:user, :admin, password: "password123") }

  describe "GET /users/sign_up" do
    it "blocks public registration" do
      expect {
        get new_user_registration_path
      }.not_to change(User, :count)

      expect(response).to redirect_to(new_user_session_path)
      expect(response.body).not_to include('name="user[email]"')
    end
  end

  describe "POST /users" do
    it "does not create a public signup user" do
      expect {
        post user_registration_path, params: {
          user: {
            name: "외부 가입자",
            email: "outsider@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      }.not_to change(User, :count)

      expect(response).to redirect_to(new_user_session_path)
      expect(User.find_by(email: "outsider@example.com")).to be_nil
      expect(User.find_by(name: "외부 가입자", role: "student")).to be_nil
    end
  end

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

    it "shows teacher avatar choices to teachers" do
      sign_in teacher

      get edit_user_registration_path

      expect(response.body).to include('name="user[avatar_key]"')
      expect(response.body).to include('value="teacherM04"')
      expect(response.body).to include('value="teacherF06"')
      expect(response.body).not_to include('name="user[avatar]"')
      expect(response.body).not_to include('value="boy01"')
      expect(response.body).not_to include('value="admin"')
      expect(response.body).not_to include('value="teacherM09"')
    end

    it "shows teacher avatar choices to admins" do
      sign_in admin

      get edit_user_registration_path

      expect(response.body).to include('name="user[avatar_key]"')
      expect(response.body).to include('value="teacherM04"')
      expect(response.body).to include('value="teacherF06"')
      expect(response.body).to include('value="admin"')
      expect(response.body).not_to include('name="user[avatar]"')
      expect(response.body).not_to include('value="boy01"')
      expect(response.body).not_to include('value="teacherM09"')
    end
  end

  describe "PATCH /users" do
    it "blocks student self-service profile updates" do
      sign_in student

      patch user_registration_path, params: {
        user: {
          name: "바뀐 학생 이름",
          email: "student@example.com"
        }
      }

      expect(response).to redirect_to(user_path(student))
      expect(student.reload.name).not_to eq("바뀐 학생 이름")
      expect(student.email).to be_nil
    end

    it "updates teacher profile attributes without requiring the current password" do
      sign_in teacher

      patch user_registration_path, params: {
        user: {
          name: "바뀐 교사 이름",
          email: teacher.email
        }
      }

      expect(response).to redirect_to(edit_user_registration_path)
      expect(teacher.reload.name).to eq("바뀐 교사 이름")
    end

    it "updates teacher gender and avatar_key without requiring the current password" do
      sign_in teacher

      patch user_registration_path, params: {
        user: {
          name: teacher.name,
          email: teacher.email,
          gender: "female",
          avatar_key: "teacherF06"
        }
      }

      expect(response).to redirect_to(edit_user_registration_path)
      expect(teacher.reload.gender).to eq("female")
      expect(teacher.avatar_key).to eq("teacherF06")
    end

    it "does not allow a teacher to save a student avatar_key" do
      teacher.update!(avatar_key: "teacherM04")
      sign_in teacher

      patch user_registration_path, params: {
        user: {
          name: teacher.name,
          email: teacher.email,
          avatar_key: "boy01"
        }
      }

      expect(response).to redirect_to(edit_user_registration_path)
      expect(teacher.reload.avatar_key).to eq("teacherM04")
    end

    it "updates admin profile attributes without requiring the current password" do
      sign_in admin

      patch user_registration_path, params: {
        user: {
          name: "바뀐 관리자 이름",
          email: admin.email
        }
      }

      expect(response).to redirect_to(edit_user_registration_path)
      expect(admin.reload.name).to eq("바뀐 관리자 이름")
    end

    it "updates admin avatar_key with a teacher avatar key" do
      admin.update!(avatar_key: "admin")
      sign_in admin

      patch user_registration_path, params: {
        user: {
          name: admin.name,
          email: admin.email,
          avatar_key: "teacherM04"
        }
      }

      expect(response).to redirect_to(edit_user_registration_path)
      expect(admin.reload.avatar_key).to eq("teacherM04")
    end

    it "does not allow an admin to save a student avatar_key" do
      admin.update!(avatar_key: "teacherF06")
      sign_in admin

      patch user_registration_path, params: {
        user: {
          name: admin.name,
          email: admin.email,
          avatar_key: "boy01"
        }
      }

      expect(response).to redirect_to(edit_user_registration_path)
      expect(admin.reload.avatar_key).to eq("teacherF06")
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
      expect(student.reload.encrypted_password).to eq("")
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
