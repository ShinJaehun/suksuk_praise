require "rails_helper"

RSpec.describe "Classroom members", type: :request do
  let(:classroom) { create(:classroom, name: "2반") }
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: "담당 교사") }
  let(:other_teacher) { create(:user, :teacher, name: "추가 교사") }

  it "shows member management sections to a classroom teacher" do
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    sign_in teacher

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("구성원 관리")
    expect(response.body).to include("2반")
    expect(response.body).to include("학생 로그인")
    expect(response.body).to include("QR 코드 보기")
    expect(response.body).to include("QR 코드 다운로드")
    expect(response.body).to include("학생 로그인 주소 재발급")
    expect(response.body).to include(public_student_login_url(student_login_token: classroom.student_login_token))
    expect(response.body).to include("학생 관리")
    expect(response.body).to include(new_classroom_student_path(classroom))
    expect(response.body).to include(bulk_new_classroom_students_path(classroom))
    expect(response.body).not_to include("담당 선생님 배정")
    expect(response.body).not_to include("classroom[teacher_ids][]")
  end

  it "shows teacher assignment controls to an admin" do
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    other_teacher
    sign_in admin

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("2반")
    expect(response.body).to include("담당 선생님 배정")
    expect(response.body).to include("담당 선생님 저장")
    expect(response.body).to include("1명 선택됨")
    expect(response.body).to include("classroom[teacher_ids][]")
    expect(response.body).to include(teacher.name)
    expect(response.body).to include(other_teacher.name)
    expect(response.body).to include("#{teacher.name} avatar")
    expect(response.body).to include("학생 로그인")
    expect(response.body).to include("학생 관리")
  end

  it "does not count a legacy admin teacher membership as an assigned teacher" do
    create(:classroom_membership, classroom: classroom, user: admin, role: "teacher")
    sign_in admin

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("담당 선생님 배정")
    expect(response.body).to include("0명 선택됨")
    expect(response.body).not_to include('checked="checked"')
  end

  it "does not show a legacy admin teacher membership in the classrooms index preview" do
    create(:classroom_membership, classroom: classroom, user: admin, role: "teacher")
    sign_in admin

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("담당 선생님 없음")
  end

  it "rejects a teacher who does not manage the classroom" do
    sign_in teacher

    get classroom_members_path(classroom)

    expect(response).to redirect_to(root_path)
  end
end
