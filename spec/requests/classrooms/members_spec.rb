require "rails_helper"

RSpec.describe "Classroom members", type: :request do
  let(:classroom) { create(:classroom, name: "2반") }
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: "담당 교사") }
  let(:other_teacher) { create(:user, :teacher, name: "추가 교사") }

  it "shows member management sections to a classroom teacher" do
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    student = create(:user, :student, name: "활성 학생", gender: "boy", avatar_key: "boy01")
    create(:classroom_membership, classroom: classroom, user: student, role: "student")
    sign_in teacher

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("구성원 관리")
    expect(response.body).to include("2반")
    expect(response.body).to include("학생 관리")
    expect(response.body).to include("활성")
    expect(response.body).to include("비활성")
    expect(response.body).to include("전체")
    expect(response.body).to include(student.name)
    expect(response.body).to include('alt="활성 학생 avatar"')
    expect(response.body).to include('form="student_names_form"')
    expect(response.body).to include(deactivate_classroom_student_path(classroom, student))
    expect(response.body).to include(new_classroom_student_path(classroom))
    expect(response.body).to include(new_classroom_student_path(classroom, return_to: "members"))
    expect(response.body).to include(bulk_new_classroom_students_path(classroom))
    expect(response.body).to include(bulk_new_classroom_students_path(classroom, return_to: "members"))
    expect(response.body).to include(classroom_member_student_names_path(classroom))
    expect(response.body).to include(edit_classroom_student_path(classroom, student))
    expect(response.body).not_to include(public_student_login_url(student_login_token: classroom.student_login_token))
    expect(response.body).not_to include("QR 코드 보기")
    expect(response.body).not_to include("QR 코드 다운로드")
    expect(response.body).not_to include("학생 로그인 주소 재발급")
    expect(response.body).not_to include("담당 선생님 배정")
    expect(response.body).not_to include("classroom[teacher_ids][]")
  end

  it "does not show teacher assignment controls to an admin" do
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    other_teacher
    sign_in admin

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("2반")
    expect(response.body).to include("학생 관리")
    expect(response.body).not_to include("담당 선생님 배정")
    expect(response.body).not_to include("담당 선생님 저장")
    expect(response.body).not_to include("classroom[teacher_ids][]")
    expect(response.body).not_to include("학생 로그인 주소 재발급")
  end

  it "filters students by active, inactive, and all status" do
    active_student = create(:user, :student, name: "김활동")
    inactive_student = create(:user, :student, name: "박휴식")
    create(:classroom_membership, classroom: classroom, user: active_student, role: "student")
    create(:classroom_membership, classroom: classroom, user: inactive_student, role: "student", status: "inactive")
    sign_in admin

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(active_student.name)
    expect(response.body).to include(edit_classroom_student_path(classroom, active_student))
    expect(response.body).to include(deactivate_classroom_student_path(classroom, active_student))
    expect(response.body).not_to include(inactive_student.name)

    get classroom_members_path(classroom, status: "inactive")

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(active_student.name)
    expect(response.body).to include(inactive_student.name)
    expect(response.body).to include(edit_classroom_student_path(classroom, inactive_student))
    expect(response.body).to include(reactivate_classroom_student_path(classroom, inactive_student))

    get classroom_members_path(classroom, status: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(active_student.name)
    expect(response.body).to include(inactive_student.name)
    expect(response.body).to include(classroom_student_path(classroom, inactive_student))
    expect(response.body).to include(deactivate_classroom_student_path(classroom, active_student))
    expect(response.body).to include(reactivate_classroom_student_path(classroom, inactive_student))
  end

  it "does not count a legacy admin teacher membership as an assigned teacher" do
    create(:classroom_membership, classroom: classroom, user: admin, role: "teacher")
    sign_in admin

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("담당 선생님 배정")
    expect(response.body).not_to include("0명 선택됨")
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

  describe "PATCH /classrooms/:classroom_id/members/students/name" do
    it "lets a classroom teacher update active student names" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      student = create(:user, :student, name: "이전 이름")
      membership = create(:classroom_membership, classroom: classroom, user: student, role: "student")
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        status: "active",
        students: {
          membership.id => { name: "새 이름" }
        }
      }

      expect(response).to redirect_to(classroom_members_path(classroom, status: "active"))
      expect(flash[:notice]).to eq(I18n.t("students.members.update_names.success"))
      expect(student.reload.name).to eq("새 이름")
    end

    it "lets a classroom teacher update inactive student names while keeping the inactive filter" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      student = create(:user, :student, name: "쉬는 학생")
      membership = create(:classroom_membership, classroom: classroom, user: student, role: "student", status: "inactive")
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        status: "inactive",
        students: {
          membership.id => { name: "돌아올 학생" }
        }
      }

      expect(response).to redirect_to(classroom_members_path(classroom, status: "inactive"))
      expect(student.reload.name).to eq("돌아올 학생")
    end

    it "lets an admin update student names" do
      student = create(:user, :student, name: "관리 전")
      membership = create(:classroom_membership, classroom: classroom, user: student, role: "student")
      sign_in admin

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: "관리 후" }
        }
      }

      expect(response).to redirect_to(classroom_members_path(classroom, status: "active"))
      expect(student.reload.name).to eq("관리 후")
    end

    it "rejects a teacher who does not manage the classroom" do
      student = create(:user, :student, name: "유지")
      membership = create(:classroom_membership, classroom: classroom, user: student, role: "student")
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: "변경 시도" }
        }
      }

      expect(response).to redirect_to(root_path)
      expect(student.reload.name).to eq("유지")
    end

    it "rejects a student" do
      student = create(:user, :student, name: "본인")
      membership = create(:classroom_membership, classroom: classroom, user: student, role: "student")
      sign_in student

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: "변경 시도" }
        }
      }

      expect(response).to redirect_to(root_path)
      expect(student.reload.name).to eq("본인")
    end

    it "fails when a membership outside the classroom is submitted" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      student = create(:user, :student, name: "내 학생")
      membership = create(:classroom_membership, classroom: classroom, user: student, role: "student")
      other_student = create(:user, :student, name: "다른 학생")
      other_membership = create(:classroom_membership, classroom: create(:classroom), user: other_student, role: "student")
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: "변경 실패" },
          other_membership.id => { name: "변경되면 안 됨" }
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("students.members.update_names.invalid_membership"))
      expect(student.reload.name).to eq("내 학생")
      expect(other_student.reload.name).to eq("다른 학생")
    end

    it "rolls back all changes and shows row errors when any name is invalid" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      valid_student = create(:user, :student, name: "유효 학생")
      invalid_student = create(:user, :student, name: "무효 학생")
      valid_membership = create(:classroom_membership, classroom: classroom, user: valid_student, role: "student")
      invalid_membership = create(:classroom_membership, classroom: classroom, user: invalid_student, role: "student")
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          valid_membership.id => { name: "저장되면 안 됨" },
          invalid_membership.id => { name: "" }
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("이름을 확인해 주세요")
      expect(response.body).to include("저장되면 안 됨")
      expect(valid_student.reload.name).to eq("유효 학생")
      expect(invalid_student.reload.name).to eq("무효 학생")
    end
  end
end
