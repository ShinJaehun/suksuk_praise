require "rails_helper"

RSpec.describe "Student PIN sessions", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:classroom) { create(:classroom) }
  let(:student) { create(:user, :student, student_pin: "1234") }
  let(:teacher) { create(:user, :teacher) }

  before do
    create(:classroom_membership, classroom: classroom, user: student, role: "student")
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
  end

  it "does not expose all classrooms and students on the global login page" do
    other_classroom = create(:classroom, name: "다른 교실")
    other_student = create(:user, :student, name: "다른 학생", student_pin: "5678")
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: "student")

    get new_student_session_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("교실별 로그인 주소")
    expect(response.body).not_to include(classroom.name)
    expect(response.body).not_to include(student.name)
    expect(response.body).not_to include(other_classroom.name)
    expect(response.body).not_to include(other_student.name)
  end

  it "shows only students from the classroom login page" do
    other_classroom = create(:classroom)
    other_student = create(:user, :student, name: "다른 학생", student_pin: "5678")
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: "student")

    get classroom_student_login_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(student.name)
    expect(response.body).to include('data-controller="student-login-preview"')
    expect(response.body).to include('data-student-login-preview-target="select"')
    expect(response.body).to include("로그인할 학생을 선택하세요")
    expect(response.body).to include("<option value=\"\">선택하세요</option>")
    expect(response.body).to include("PIN을 입력하세요")
    expect(response.body).to include("suksuk_logo")
    expect(response.body).not_to include('alt="선택하세요"')
    expect(response.body).to include("data-avatar-url=")
    expect(response.body).to include("data-student-name=\"#{student.name}\"")
    expect(response.body).not_to include("선택한 학생의 아바타가 여기에 표시됩니다.")
    expect(response.body).not_to include(other_student.name)
  end

  it "shows only students from the token classroom login page" do
    other_classroom = create(:classroom)
    other_student = create(:user, :student, name: "다른 학생", student_pin: "5678")
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: "student")

    get public_student_login_path(student_login_token: classroom.student_login_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(student.name)
    expect(response.body).to include(public_student_login_path(student_login_token: classroom.student_login_token))
    expect(response.body).to include('data-controller="student-login-preview"')
    expect(response.body).to include('data-student-login-preview-target="select"')
    expect(response.body).to include("로그인할 학생을 선택하세요")
    expect(response.body).to include("<option value=\"\">선택하세요</option>")
    expect(response.body).to include("PIN을 입력하세요")
    expect(response.body).to include("suksuk_logo")
    expect(response.body).not_to include('alt="선택하세요"')
    expect(response.body).to include("data-avatar-url=")
    expect(response.body).to include("data-student-name=\"#{student.name}\"")
    expect(response.body).not_to include("선택한 학생의 아바타가 여기에 표시됩니다.")
    expect(response.body).not_to include(other_student.name)
  end

  it "returns not found for an invalid student login token" do
    get public_student_login_path(student_login_token: "invalid-token")

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("학생 로그인 주소를 사용할 수 없습니다.")
    expect(response.body).to include("새 QR 코드나 로그인 주소")
  end

  it "signs in a student with classroom, student, and PIN" do
    post classroom_student_login_path(classroom), params: {
      student_id: student.id,
      student_pin: "1234"
    }

    expect(response).to redirect_to(classroom_student_path(classroom, student))
  end

  it "signs in a student through the token classroom login route" do
    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: "1234"
    }

    expect(response).to redirect_to(classroom_student_path(classroom, student))
    expect(session[:student_login_classroom_id]).to eq(classroom.id)
  end

  it "stores the student session last seen timestamp after PIN login" do
    post classroom_student_login_path(classroom), params: {
      student_id: student.id,
      student_pin: "1234"
    }

    expect(session[:student_login_classroom_id]).to eq(classroom.id)
    expect(session[:student_last_seen_at]).to be_present
  end

  it "keeps a student signed in within the TTL and refreshes last seen" do
    travel_to Time.zone.local(2026, 5, 22, 10, 0, 0) do
      post classroom_student_login_path(classroom), params: {
        student_id: student.id,
        student_pin: "1234"
      }
    end

    travel_to Time.zone.local(2026, 5, 22, 10, 5, 0) do
      get classroom_student_path(classroom, student)
    end

    expect(response).to have_http_status(:ok)
    expect(session[:student_last_seen_at]).to eq(Time.zone.local(2026, 5, 22, 10, 5, 0).to_i)
  end

  it "redirects an expired student session to the classroom PIN login page" do
    travel_to Time.zone.local(2026, 5, 22, 10, 0, 0) do
      post classroom_student_login_path(classroom), params: {
        student_id: student.id,
        student_pin: "1234"
      }
    end

    travel_to Time.zone.local(2026, 5, 22, 10, 21, 1) do
      get classroom_student_path(classroom, student)
    end

    expect(response).to redirect_to(classroom_student_login_path(classroom))
    expect(controller.current_user).to be_nil
  end

  it "falls back to the global student login page when an expired session has no classroom" do
    sign_in student

    travel_to Time.zone.local(2026, 5, 22, 10, 0, 0) do
      get classroom_student_path(classroom, student)
    end

    travel_to Time.zone.local(2026, 5, 22, 10, 21, 1) do
      get user_path(student)
    end

    expect(response).to redirect_to(new_student_session_path)
    expect(controller.current_user).to be_nil
  end

  it "initializes missing student last seen without expiring the session" do
    sign_in student

    get user_path(student)

    expect(response).to redirect_to(classroom_student_path(classroom, student))
    expect(session[:student_last_seen_at]).to be_present
  end

  it "redirects student logout back to the classroom PIN login page" do
    post classroom_student_login_path(classroom), params: {
      student_id: student.id,
      student_pin: "1234"
    }

    expect(session[:student_login_classroom_id]).to eq(classroom.id)

    delete destroy_student_session_path

    expect(response).to redirect_to(classroom_student_login_path(classroom))
  end

  it "falls back to the global student login page without a stored classroom" do
    sign_in student

    delete destroy_student_session_path

    expect(response).to redirect_to(new_student_session_path)
  end

  it "shows a student-specific logout link on the self page" do
    sign_in student

    get classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("사용 끝내기")
    expect(response.body).to include(destroy_student_session_path)
    expect(response.body).not_to include(destroy_user_session_path)
  end

  it "does not apply student TTL to a teacher" do
    sign_in teacher

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(controller.current_user).to eq(teacher)
  end

  it "rejects an invalid PIN" do
    post classroom_student_login_path(classroom), params: {
      student_id: student.id,
      student_pin: "0000"
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("학생 PIN 로그인")
  end

  it "rejects a student outside the classroom" do
    other_classroom = create(:classroom)
    other_student = create(:user, :student, student_pin: "5678")
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: "student")

    post classroom_student_login_path(classroom), params: {
      student_id: other_student.id,
      student_pin: "5678"
    }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "renders the managed student PIN field as an empty password input with the default PIN status" do
    sign_in teacher

    get edit_classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('type="password"')
    expect(response.body).to include('name="user[student_pin]"')
    expect(response.body).to include("현재 PIN:")
    expect(response.body).to include("기본 PIN(1234)으로 설정됨")
    expect(response.body).to include("새 PIN을 입력하면 변경됩니다. 비워두면 기존 PIN을 유지합니다.")
    expect(response.body).not_to include(student.student_pin_digest)
  end

  it "shows the custom PIN status after the managed PIN changes from 1234" do
    student.update!(student_pin: "4321")
    sign_in teacher

    get edit_classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("현재 PIN:")
    expect(response.body).to include("설정됨")
    expect(response.body).not_to include("기본 PIN(1234)으로 설정됨")
  end

  it "shows the unset PIN status for a student without a PIN" do
    student.update_column(:student_pin_digest, nil)
    sign_in teacher

    get edit_classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("현재 PIN:")
    expect(response.body).to include("미설정")
  end

  it "lets a teacher update the student PIN and then sign in with it" do
    sign_in teacher

    patch classroom_student_path(classroom, student), params: {
      user: {
        name: student.name,
        email: student.email,
        student_pin: "4321"
      }
    }

    expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
    expect(User.find(student.id).authenticate_student_pin("4321")).to be_truthy

    delete destroy_user_session_path

    post classroom_student_login_path(classroom), params: {
      student_id: student.id,
      student_pin: "4321"
    }

    expect(response).to redirect_to(classroom_student_path(classroom, student))
  end

  it "keeps the existing student PIN when the managed PIN field is blank" do
    original_digest = student.student_pin_digest
    sign_in teacher

    patch classroom_student_path(classroom, student), params: {
      user: {
        name: "새 이름",
        email: student.email,
        student_pin: ""
      }
    }

    expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
    expect(student.reload.student_pin_digest).to eq(original_digest)
    expect(student.authenticate_student_pin("1234")).to be_truthy
  end

  it "rejects an invalid managed student PIN format" do
    original_digest = student.student_pin_digest
    sign_in teacher

    patch classroom_student_path(classroom, student), params: {
      user: {
        name: student.name,
        email: student.email,
        student_pin: "12ab"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(student.reload.student_pin_digest).to eq(original_digest)
  end
end
