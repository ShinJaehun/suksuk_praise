require "rails_helper"

RSpec.describe "Classroom student login link", type: :request do
  let(:classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user, :student) }

  it "shows the token student login URL to a classroom teacher" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("학생 로그인 주소")
    expect(response.body).to include(public_student_login_url(student_login_token: classroom.student_login_token))
  end

  it "shows the token student login URL to an admin" do
    sign_in admin

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(public_student_login_url(student_login_token: classroom.student_login_token))
  end

  it "does not expose the token student login URL to a student" do
    create(:classroom_membership, user: student, classroom: classroom, role: "student")
    sign_in student

    get classroom_path(classroom)

    expect(response).to redirect_to(user_path(student))
    expect(response.body).not_to include(classroom.student_login_token)
  end
end
