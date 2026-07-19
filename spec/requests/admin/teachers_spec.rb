require "rails_helper"

RSpec.describe "Admin teachers", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: "담당 교사") }

  it "shows the teacher management index to an admin" do
    school = create(:school, name: "새싹초등학교")
    other_school = create(:school, name: "나래초등학교")
    classroom = create(:classroom, school: school, grade: 4, name: "4학년 1반")
    manager = create(:school_membership, :manager, school: school, user: teacher).user
    member_teacher = create(:school_membership, school: school, user: create(:user, :teacher, name: "일반 선생님")).user
    unassigned_teacher = create(:user, :teacher, name: "미배정 선생님")
    create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
    sign_in admin

    get admin_teachers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("선생님 관리")
    expect(response.body).to include("선생님 추가")
    expect(response.body).to include('id="teacher-school-filter"')
    expect(response.body).to include('name="school_id"')
    expect(response.body).to include("전체 학교")
    expect(response.body).to include(school.name, other_school.name)
    expect(response.body).to include("담당 교사", "새싹초등학교", "학교 관리자", "4학년 1반", "4학년")
    expect(response.body).to include("일반 선생님", "일반 구성원")
    expect(response.body).to include("미배정 선생님", "학교 미지정", "해당 없음", "담당 교실 없음")
    expect(response.body).to include(new_admin_teacher_path)
    expect(response.body).to include(edit_admin_teacher_path(manager))
    expect(response.body).to include(edit_admin_teacher_path(member_teacher))
    expect(response.body).to include('data-turbo-frame="modal"')
  end

  it "filters the teacher management index by school" do
    school = create(:school, name: "새싹초등학교")
    other_school = create(:school, name: "나래초등학교")
    school_teacher = create(:school_membership, school: school, user: create(:user, :teacher, name: "새싹 선생님")).user
    other_school_teacher = create(:school_membership, school: other_school, user: create(:user, :teacher, name: "나래 선생님")).user
    unassigned_teacher = create(:user, :teacher, name: "미배정 선생님")
    sign_in admin

    get admin_teachers_path, params: { school_id: school.id }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="teacher-school-filter"')
    expect(response.body).to match(%r{<option selected="selected" value="#{school.id}">#{school.name}</option>})
    expect(response.body).to include(school_teacher.name, school_teacher.email, edit_admin_teacher_path(school_teacher))
    expect(response.body).not_to include(other_school_teacher.name)
    expect(response.body).not_to include(edit_admin_teacher_path(other_school_teacher))
    expect(response.body).not_to include(unassigned_teacher.name)
  end

  it "treats an invalid teacher school filter as the full teacher list" do
    school_teacher = create(:school_membership, school: create(:school), user: create(:user, :teacher, name: "소속 선생님")).user
    unassigned_teacher = create(:user, :teacher, name: "미배정 선생님")
    sign_in admin

    get admin_teachers_path, params: { school_id: "missing" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(school_teacher.name, unassigned_teacher.name)
    expect(response.body).to include("학교 미지정")
    expect(response.body).not_to include('selected="selected" value="missing"')
  end

  it "shows an empty state on the teacher management index" do
    sign_in admin

    get admin_teachers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("등록된 선생님이 없습니다.")
    expect(response.body).to include(new_admin_teacher_path)
    expect(response.body).to include('data-turbo-frame="modal"')
  end

  it "keeps the new teacher page fallback" do
    sign_in admin

    get new_admin_teacher_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("새 선생님 추가")
    expect(response.body).to include("선생님 관리로 돌아가기")
    expect(response.body).to match(%r{src="[^"]*avatars/teacher[MF]\d{2}[^"]*\.png"})
    expect(response.body).to include('name="user[gender]"')
    expect(response.body).to include('name="user[avatar_key]"')
    expect(response.body).not_to include('type="radio"')
  end

  it "targets modal form submissions to the top frame" do
    sign_in admin

    get new_admin_teacher_path, headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include("새 선생님 추가")
    expect(response.body).to include('data-turbo-frame="_top"')
    expect(response.body).to include('data-turbo-submits-with="저장 중..."')
    expect(response.body).not_to include("<!DOCTYPE html>")
    expect(response.body).not_to include("translation missing")
    expect(response.body).to match(%r{src="[^"]*avatars/teacher[MF]\d{2}[^"]*\.png"})
    expect(response.body).to include('name="user[gender]"')
    expect(response.body).to include('name="user[avatar_key]"')
  end

  it "saves a submitted male teacher avatar_key for male gender" do
    sign_in admin

    post admin_teachers_path, params: {
      user: {
        name: "남자 교사",
        email: "male-teacher@example.com",
        password: "password123",
        gender: "male",
        avatar_key: "teacherM01"
      }
    }

    expect(User.teacher.find_by!(email: "male-teacher@example.com").avatar_key).to eq("teacherM01")
  end

  it "saves a submitted female teacher avatar_key for female gender" do
    sign_in admin

    post admin_teachers_path, params: {
      user: {
        name: "여자 교사",
        email: "female-teacher@example.com",
        password: "password123",
        gender: "female",
        avatar_key: "teacherF01"
      }
    }

    expect(User.teacher.find_by!(email: "female-teacher@example.com").avatar_key).to eq("teacherF01")
  end

  it "assigns any teacher avatar_key when gender is blank or invalid" do
    sign_in admin

    ["", "unknown"].each_with_index do |gender, index|
      post admin_teachers_path, params: {
        user: {
          name: "기본 아바타 교사 #{index}",
          email: "default-avatar-teacher-#{index}@example.com",
          password: "password123",
          gender: gender
        }
      }

      expect(User.teacher.find_by!(email: "default-avatar-teacher-#{index}@example.com").avatar_key).to be_in(User.avatar_keys_for_role("teacher"))
    end
  end

  it "replaces an avatar_key that does not match gender" do
    sign_in admin

    post admin_teachers_path, params: {
      user: {
        name: "조작 방지 교사",
        email: "ignored-avatar-teacher@example.com",
        password: "password123",
        gender: "male",
        avatar_key: "teacherF01"
      }
    }

    expect(User.teacher.find_by!(email: "ignored-avatar-teacher@example.com").avatar_key).to be_in(User::TEACHER_MALE_AVATAR_KEYS)
  end

  it "keeps gender and avatar preview when teacher creation fails" do
    sign_in admin

    post admin_teachers_path, params: {
      user: {
        name: "",
        email: "invalid-teacher@example.com",
        password: "password123",
        gender: "female"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('<option selected="selected" value="female">여자</option>')
    avatar_key = response.body[%r{<input(?=[^>]*name="user\[avatar_key\]")(?=[^>]*value="(teacherF\d{2})")[^>]*>}, 1]
    expect(avatar_key).to be_present
    expect(response.body).to match(%r{src="[^"]*avatars/#{avatar_key}[^"]*\.png"})
  end

  it "opens teacher school membership links from the teacher management index in the modal frame" do
    teacher
    sign_in admin

    get admin_teachers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_teacher_path(teacher))
    expect(response.body).to include('data-turbo-frame="modal"')
  end

  it "keeps the teacher school membership page fallback" do
    sign_in admin

    get edit_admin_teacher_path(teacher)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("선생님 학교 소속")
    expect(response.body).to include("선생님 관리로 돌아가기")
    expect(response.body).to include('data-turbo-frame="_top"')
  end

  it "renders teacher school membership in the modal frame" do
    sign_in admin

    get edit_admin_teacher_path(teacher), headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include("선생님 학교 소속")
    expect(response.body).to include('data-turbo-frame="_top"')
    expect(response.body).to include('data-turbo-submits-with="저장 중..."')
    expect(response.body).not_to include("<!DOCTYPE html>")
    expect(response.body).to include("선생님 관리로 돌아가기")
    expect(response.body).not_to include("translation missing")
  end

  it "blocks non-admin users from the teacher management index" do
    manager = create(:school_membership, :manager).user
    regular_teacher = create(:user, :teacher)
    student = create(:user, :student)

    [manager, regular_teacher, student].each do |user|
      sign_in user
      get admin_teachers_path
      expect(response).to redirect_to(root_path)
    end
  end

  it "blocks non-admin users from teacher management actions" do
    manager = create(:school_membership, :manager).user
    regular_teacher = create(:user, :teacher)
    student = create(:user, :student)

    [manager, regular_teacher, student].each do |user|
      sign_in user

      get new_admin_teacher_path
      expect(response).to redirect_to(root_path)

      expect do
        post admin_teachers_path, params: {
          user: {
            name: "차단된 선생님",
            email: "blocked-#{user.id}@example.com",
            password: "password123"
          }
        }
      end.not_to change { User.teacher.count }
      expect(response).to redirect_to(root_path)

      get edit_admin_teacher_path(teacher)
      expect(response).to redirect_to(root_path)

      patch admin_teacher_path(teacher), params: { school_id: "" }
      expect(response).to redirect_to(root_path)
    end
  end

  it "requires authentication for the teacher management index" do
    get admin_teachers_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows the teacher management navigation link only to admins" do
    manager_membership = create(:school_membership, :manager)
    regular_teacher = create(:user, :teacher)
    student = create(:user, :student)

    sign_in admin
    get schools_path
    expect(response.body).to include(admin_teachers_path)
    expect(response.body).to include(schools_path, classrooms_path)

    sign_in manager_membership.user
    assigned_classroom = create(:classroom, school: manager_membership.school)
    create(:classroom_membership, classroom: assigned_classroom, user: manager_membership.user, role: :teacher)
    get school_teachers_path(manager_membership.school)
    expect(response.body).not_to include(admin_teachers_path)
    expect(response.body).to include(school_path(manager_membership.school))
    expect(response.body).to include(classrooms_path)
    expect(response.body).to include(school_teachers_path(manager_membership.school))
    expect(response.body).not_to include(classroom_path(assigned_classroom))

    sign_in regular_teacher
    get classrooms_path
    expect(response.body).not_to include(admin_teachers_path)
    expect(response.body).not_to include(school_teachers_path(manager_membership.school))
    expect(response.body).not_to include(school_path(manager_membership.school))

    sign_in student
    get user_path(student)
    expect(response.body).not_to include(admin_teachers_path)
  end

  it "ignores classroom assignment params while selecting a school" do
    school = create(:school)
    classroom = create(:classroom, school: school)
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: school.id,
      classroom_ids: [classroom.id]
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.school_membership).to have_attributes(school: school)
    expect(teacher.classroom_memberships.teacher).to be_empty
  end

  it "ignores multiple forged classroom assignment params" do
    school = create(:school)
    classrooms = create_list(:classroom, 2, school: school)
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: school.id,
      classroom_ids: classrooms.map(&:id)
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.school_membership).to have_attributes(school: school)
    expect(teacher.classroom_memberships.teacher).to be_empty
  end

  it "ignores forged classroom ids but rejects a conflicting school change" do
    original_school = create(:school)
    selected_school = create(:school)
    other_school = create(:school)
    existing_classroom = create(:classroom, school: original_school)
    selected_classroom = create(:classroom, school: selected_school)
    other_classroom = create(:classroom, school: other_school)
    create(:school_membership, school: original_school, user: teacher)
    create(:classroom_membership, classroom: existing_classroom, user: teacher, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: {
        school_id: selected_school.id,
        classroom_ids: [selected_classroom.id, other_classroom.id]
      },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body).to include("담당 학급을 먼저 모두 해제한 뒤 학교 소속을 변경하거나 삭제해 주세요.")
    expect(teacher.reload.school_membership).to have_attributes(school: original_school)
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(existing_classroom.id)
    expect(teacher.classroom_memberships.teacher.where(classroom: [selected_classroom, other_classroom])).to be_empty
  end

  it "rejects a school change while classroom assignments remain" do
    original_school = create(:school)
    new_school = create(:school)
    old_classroom = create(:classroom, school: original_school)
    create(:school_membership, school: original_school, user: teacher)
    membership = create(:classroom_membership, classroom: old_classroom, user: teacher, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { school_id: new_school.id },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("담당 학급을 먼저 모두 해제한 뒤 학교 소속을 변경하거나 삭제해 주세요.")
    expect(teacher.reload.school_membership).to have_attributes(school: original_school)
    expect(teacher.classroom_memberships.teacher.pluck(:id)).to contain_exactly(membership.id)
  end

  it "allows selecting a school without classrooms" do
    school = create(:school)
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: school.id,
      classroom_ids: [""]
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.school_membership).to have_attributes(school: school)
    expect(teacher.classroom_memberships.teacher).to be_empty
  end

  it "rejects clearing school while classroom assignments remain" do
    school = create(:school)
    classroom = create(:classroom, school: school)
    create(:school_membership, school: school, user: teacher)
    membership = create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { school_id: "", classroom_ids: [""] },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body).to include("담당 학급을 먼저 모두 해제한 뒤 학교 소속을 변경하거나 삭제해 주세요.")
    expect(teacher.reload.school_membership).to have_attributes(school: school)
    expect(teacher.classroom_memberships.teacher.pluck(:id)).to contain_exactly(membership.id)
  end

  it "ignores classroom assignments without a selected school" do
    school = create(:school)
    classroom = create(:classroom, school: school)
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: "",
      classroom_ids: [classroom.id]
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.school_membership).to be_nil
    expect(teacher.classroom_memberships.teacher).to be_empty
  end

  it "ignores a missing classroom id without changing assignments" do
    school = create(:school)
    classroom = create(:classroom, school: school)
    existing_classroom = create(:classroom, school: school)
    create(:school_membership, school: school, user: teacher)
    create(:classroom_membership, classroom: existing_classroom, user: teacher, role: :teacher)
    missing_id = Classroom.maximum(:id).to_i + 10_000
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: school.id,
      classroom_ids: [classroom.id, missing_id]
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.school_membership).to have_attributes(school: school)
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(existing_classroom.id)
  end

  it "does not show classroom assignment inputs in the edit form" do
    school = create(:school)
    other_school = create(:school)
    classroom = create(:classroom, school: school, name: "현재 학교 학급")
    other_classroom = create(:classroom, school: other_school, name: "다른 학교 학급")
    create(:school_membership, school: school, user: teacher)
    sign_in admin

    get edit_admin_teacher_path(teacher)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("담당 학급은 해당 학교의 선생님 관리 화면에서 배정합니다.")
    expect(response.body).to include(school_teachers_path(school))
    expect(response.body).not_to include(%(name="classroom_ids[]"))
    expect(response.body).not_to include(classroom.name)
    expect(response.body).not_to include(other_classroom.name)
    expect(response.body).not_to include(%(value="#{other_classroom.id}"))
  end
end
