require "rails_helper"

RSpec.describe "Classroom student login link", type: :request do
  let(:classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user, :student) }

  it "does not show the token student login URL on the classroom show page" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("학생 로그인 주소")
    expect(response.body).not_to include(classroom.student_login_token)
    expect(response.body).not_to include(public_student_login_url(student_login_token: classroom.student_login_token))
  end

  it "shows the token student login URL to a classroom teacher on the edit page" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    get edit_classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("학생 로그인 주소")
    expect(response.body).to include(public_student_login_url(student_login_token: classroom.student_login_token))
    expect(response.body).to include("URL 복사")
    expect(response.body).to include("학생 로그인 주소 재발급")
  end

  it "shows the token student login URL to an admin on the edit page" do
    sign_in admin

    get edit_classroom_path(classroom)

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

  it "does not allow a non-managing teacher to access token management" do
    sign_in teacher

    get edit_classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include(classroom.student_login_token)
  end

  it "regenerates the student login token for a classroom teacher" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    old_token = classroom.student_login_token
    sign_in teacher

    patch regenerate_student_login_token_classroom_path(classroom)

    expect(response).to redirect_to(edit_classroom_path(classroom))
    expect(flash[:notice]).to include("학생 로그인 주소를 재발급했습니다.")
    expect(flash[:notice]).to include("기존에 복사해 둔 주소와 기존 QR 코드는 더 이상 사용할 수 없습니다.")
    expect(flash[:notice]).to include("아래 새 주소를 다시 복사해서 학생들에게 안내해 주세요.")
    expect(classroom.reload.student_login_token).not_to eq(old_token)
  end

  it "expires the old token route and keeps the new token route available after regeneration" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    old_token = classroom.student_login_token
    sign_in teacher

    patch regenerate_student_login_token_classroom_path(classroom)
    new_token = classroom.reload.student_login_token
    delete destroy_user_session_path

    get public_student_login_path(student_login_token: old_token)
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("학생 로그인 주소를 사용할 수 없습니다.")

    get public_student_login_path(student_login_token: new_token)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("학생 PIN 로그인")
  end

  it "does not allow a non-managing teacher to regenerate the token" do
    old_token = classroom.student_login_token
    sign_in teacher

    patch regenerate_student_login_token_classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(classroom.reload.student_login_token).to eq(old_token)
  end
end
