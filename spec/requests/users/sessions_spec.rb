require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  let(:teacher) { create(:user, :teacher, password: "password123") }
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:student) { create(:user, :student, password: "password123", student_pin: "1234") }
  let(:classroom) { create(:classroom) }

  before do
    create(:classroom_membership, classroom: classroom, user: student, role: "student")
  end

  it "allows a teacher to sign in with Devise" do
    post user_session_path, params: {
      user: {
        email: teacher.email,
        password: "password123"
      }
    }

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(controller.current_user).to eq(teacher)
  end

  it "keeps the teacher Devise sign out path available" do
    sign_in teacher

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sign out")
    expect(response.body).to include(destroy_user_session_path)
    expect(response.body).not_to include(destroy_student_session_path)
  end

  it "allows an admin to sign in with Devise" do
    post user_session_path, params: {
      user: {
        email: admin.email,
        password: "password123"
      }
    }

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(controller.current_user).to eq(admin)
  end

  it "blocks a student from signing in with Devise" do
    post user_session_path, params: {
      user: {
        email: student.email,
        password: "password123"
      }
    }

    expect(response).to redirect_to(new_student_session_path)
    follow_redirect!
    expect(response.body).to include("학생은 교실별 PIN 로그인으로 접속해 주세요.")
    expect(controller.current_user).to be_nil
  end

  it "still allows a student to sign in with the classroom PIN flow" do
    post classroom_student_login_path(classroom), params: {
      student_id: student.id,
      student_pin: "1234"
    }

    expect(response).to redirect_to(user_path(student))
  end
end
