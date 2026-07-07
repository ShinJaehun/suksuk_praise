require "rails_helper"

RSpec.describe "Classroom student login link", type: :request do
  let(:classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user, :student) }

  it "shows the student login modal link without exposing the token URL on the classroom show page" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("학생 로그인")
    expect(response.body).to include(student_login_info_classroom_path(classroom))
    expect(response.body).to include('data-turbo-frame="modal"')
    expect(response.body).to include("구성원 관리")
    expect(response.body).to include(classroom_members_path(classroom))
    expect(response.body).not_to include("학생 로그인 주소")
    expect(response.body).not_to include("QR 코드 보기")
    expect(response.body).not_to include(classroom.student_login_token)
    expect(response.body).not_to include(public_student_login_url(student_login_token: classroom.student_login_token))
  end

  it "shows actual homeroom teachers to an admin on the classroom show page" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in admin

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(teacher.name)
    expect(response.body).to include("#{teacher.name} avatar")
  end

  it "does not show a legacy admin teacher membership as a homeroom teacher" do
    admin.update!(name: "레거시 관리자")
    create(:classroom_membership, user: admin, classroom: classroom, role: "teacher")
    sign_in admin

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("담당 교사 없음")
  end

  it "shows the token student login controls to a classroom teacher in the modal" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    get student_login_info_classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("학생 로그인")
    expect(response.body).to include(public_student_login_url(student_login_token: classroom.student_login_token))
    expect(response.body).to include("URL 복사")
    expect(response.body).to include("QR 코드 보기")
    expect(response.body).to include(student_login_qr_classroom_path(classroom))
    expect(response.body).to include("QR 코드 다운로드")
    expect(response.body).to include(download_student_login_qr_classroom_path(classroom))
    expect(response.body).to include("학생 로그인 주소 재발급")
  end

  it "shows the token student login controls to an admin in the modal" do
    sign_in admin

    get student_login_info_classroom_path(classroom)

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

  it "does not allow a student to access the student login info modal" do
    create(:classroom_membership, user: student, classroom: classroom, role: "student")
    sign_in student

    get student_login_info_classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include(classroom.student_login_token)
  end

  it "does not allow a non-managing teacher to access token management" do
    sign_in teacher

    get student_login_info_classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include(classroom.student_login_token)
  end

  it "does not show student login controls on the members page" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(public_student_login_url(student_login_token: classroom.student_login_token))
    expect(response.body).not_to include("URL 복사")
    expect(response.body).not_to include("QR 코드 보기")
    expect(response.body).not_to include("QR 코드 다운로드")
    expect(response.body).not_to include("학생 로그인 주소 재발급")
  end

  it "shows the student login QR page to a classroom teacher" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    get student_login_qr_classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("학생 로그인 QR 코드")
    expect(response.body).to include("data:image/png;base64,")
    expect(response.body).to include(public_student_login_url(student_login_token: classroom.student_login_token))
  end

  it "shows the student login QR page to an admin" do
    sign_in admin

    get student_login_qr_classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("data:image/png;base64,")
    expect(response.body).to include(public_student_login_url(student_login_token: classroom.student_login_token))
  end

  it "downloads the student login QR PNG for a classroom teacher" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    get download_student_login_qr_classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
    expect(response.body.bytes.first(4)).to eq([137, 80, 78, 71])
  end

  it "does not allow a non-managing teacher to download the QR PNG" do
    sign_in teacher

    get download_student_login_qr_classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include(classroom.student_login_token)
  end

  it "does not allow a student to download the QR PNG" do
    create(:classroom_membership, user: student, classroom: classroom, role: "student")
    sign_in student

    get download_student_login_qr_classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include(classroom.student_login_token)
  end

  it "does not allow a non-managing teacher to access the QR page" do
    sign_in teacher

    get student_login_qr_classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include(classroom.student_login_token)
  end

  it "does not allow a student to access the QR page" do
    create(:classroom_membership, user: student, classroom: classroom, role: "student")
    sign_in student

    get student_login_qr_classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include(classroom.student_login_token)
  end

  it "regenerates the student login token for a classroom teacher" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    old_token = classroom.student_login_token
    sign_in teacher

    patch regenerate_student_login_token_classroom_path(classroom)

    expect(response).to redirect_to(classroom_path(classroom))
    expect(flash[:notice]).to include("학생 로그인 주소를 재발급했습니다.")
    expect(flash[:notice]).to include("기존에 복사해 둔 주소와 기존 QR 코드는 더 이상 사용할 수 없습니다.")
    expect(flash[:notice]).to include("아래 새 주소를 다시 복사하거나 QR 코드를 다시 안내하세요.")
    expect(classroom.reload.student_login_token).not_to eq(old_token)
  end

  it "uses the new token URL on the QR page after regeneration" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    old_token = classroom.student_login_token
    sign_in teacher

    patch regenerate_student_login_token_classroom_path(classroom)
    new_token = classroom.reload.student_login_token

    get student_login_qr_classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(public_student_login_url(student_login_token: new_token))
    expect(response.body).not_to include(public_student_login_url(student_login_token: old_token))
  end

  it "downloads a QR PNG after regeneration" do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher

    patch regenerate_student_login_token_classroom_path(classroom)

    get download_student_login_qr_classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
    expect(response.body.bytes.first(4)).to eq([137, 80, 78, 71])
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
