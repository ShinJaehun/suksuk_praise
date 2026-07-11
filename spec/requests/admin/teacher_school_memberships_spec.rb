require "rails_helper"

RSpec.describe "Admin teacher school memberships", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: "담당 교사") }
  let(:school) { create(:school, name: "가온초등학교") }
  let(:other_school) { create(:school, name: "나래초등학교") }

  it "shows the current school and classroom organization in the edit modal" do
    classroom = create(:classroom, school: school, grade: 4, name: "4학년 1반")
    create(:school_membership, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in admin

    get edit_admin_teacher_path(teacher), headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to match(/<option selected="selected" value="#{school.id}">#{school.name}<\/option>/)
    expect(response.body).to include("#{school.name} · 4학년")
    expect(response.body).not_to include("<!DOCTYPE html>")
  end

  it "creates a teacher with a school membership" do
    sign_in admin

    post admin_teachers_path, params: {
      user: valid_teacher_params,
      school_id: school.id
    }

    created_teacher = User.teacher.find_by!(email: valid_teacher_params[:email])
    expect(response).to redirect_to(classrooms_path)
    expect(created_teacher.school).to eq(school)
  end

  it "creates a teacher without a school" do
    sign_in admin

    post admin_teachers_path, params: {
      user: valid_teacher_params,
      school_id: ""
    }

    created_teacher = User.teacher.find_by!(email: valid_teacher_params[:email])
    expect(response).to redirect_to(classrooms_path)
    expect(created_teacher.school_membership).to be_nil
  end

  it "rolls back teacher creation for a school id that does not exist" do
    sign_in admin

    expect do
      post admin_teachers_path,
        params: { user: valid_teacher_params, school_id: School.maximum(:id).to_i + 10_000 },
        headers: { "Accept" => Mime[:turbo_stream].to_s }
    end.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include("선택한 학교를 찾을 수 없습니다.")
    expect(response.body).not_to include("<!DOCTYPE html>")
  end

  it "keeps a failed create and its selected school in the modal" do
    sign_in admin

    post admin_teachers_path,
      params: { user: valid_teacher_params.merge(name: ""), school_id: school.id },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include(%(value="#{valid_teacher_params[:email]}"))
    expect(response.body).to include('<option selected="selected" value="female">여자</option>')
    expect(response.body).to include(%(value="#{valid_teacher_params[:avatar_key]}"))
    expect(response.body).to include('name="school_id"')
    expect(response.body).to match(/<option selected="selected" value="#{school.id}">#{school.name}<\/option>/)
    expect(response.body).not_to include("<!DOCTYPE html>")
  end

  it "redirects the top frame after a successful modal create" do
    sign_in admin

    post admin_teachers_path,
      params: { user: valid_teacher_params, school_id: school.id },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    created_teacher = User.teacher.find_by!(email: valid_teacher_params[:email])
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(classrooms_path)
    expect(created_teacher.school).to eq(school)
    expect(response.body).not_to include('turbo-stream action="refresh"')
  end

  it "changes and removes a teacher school membership" do
    create(:school_membership, user: teacher, school: school)
    sign_in admin

    patch admin_teacher_path(teacher), params: { school_id: other_school.id }
    expect(teacher.reload.school).to eq(other_school)

    patch admin_teacher_path(teacher), params: { school_id: "" }
    expect(teacher.reload.school_membership).to be_nil
  end

  it "keeps a failed update and its selected school in the modal" do
    classroom = create(:classroom, school: other_school)
    create(:school_membership, user: teacher, school: school)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { user: { name: "" }, school_id: other_school.id, classroom_ids: [classroom.id] },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to match(/<option selected="selected" value="#{other_school.id}">#{other_school.name}<\/option>/)
    expect(response.body).to match(/<input(?=[^>]*name="classroom_ids\[\]")(?=[^>]*value="#{classroom.id}")(?=[^>]*checked="checked")[^>]*>/)
    expect(response.body).not_to include("<!DOCTYPE html>")
    expect(teacher.reload.school).to eq(school)
  end

  it "redirects the top frame after a successful modal update" do
    classroom = create(:classroom, school: other_school)
    create(:school_membership, user: teacher, school: school)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { school_id: other_school.id, classroom_ids: [classroom.id] },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(classrooms_path)
    expect(teacher.reload.school).to eq(other_school)
    expect(teacher.classroom_memberships.teacher.exists?(classroom: classroom)).to eq(true)
    expect(response.body).not_to include('turbo-stream action="refresh"')
  end

  it "keeps the existing school when school_id is not submitted" do
    create(:school_membership, user: teacher, school: school)
    classroom = create(:classroom)
    sign_in admin

    patch admin_teacher_path(teacher), params: { classroom_ids: [classroom.id] }

    expect(teacher.reload.school).to eq(school)
    expect(teacher.classroom_memberships.teacher.exists?(classroom: classroom)).to eq(true)
  end

  it "keeps classroom assignments when classroom_ids is not submitted" do
    classroom = create(:classroom)
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in admin

    patch admin_teacher_path(teacher), params: { school_id: school.id }

    expect(teacher.reload.school).to eq(school)
    expect(teacher.classroom_memberships.teacher.exists?(classroom: classroom)).to eq(true)
  end

  it "removes every classroom assignment for an explicitly blank classroom_ids value" do
    classroom = create(:classroom)
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in admin

    patch admin_teacher_path(teacher), params: { classroom_ids: [""] }

    expect(teacher.classroom_memberships.teacher).to be_empty
  end

  it "changes school and classroom assignments in one request" do
    previous_classroom = create(:classroom, school: school)
    next_classroom = create(:classroom, school: other_school)
    create(:school_membership, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: previous_classroom, role: "teacher")
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: other_school.id,
      classroom_ids: [next_classroom.id]
    }

    expect(teacher.reload.school).to eq(other_school)
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to eq([next_classroom.id])
  end

  it "rolls back all assignment changes when the user update is invalid" do
    classroom = create(:classroom, school: school)
    other_classroom = create(:classroom, school: other_school)
    create(:school_membership, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      user: { name: "" },
      school_id: other_school.id,
      classroom_ids: [other_classroom.id]
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(teacher.reload.school).to eq(school)
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to eq([classroom.id])
  end

  it "keeps existing assignments for an invalid school id" do
    classroom = create(:classroom, school: school)
    create(:school_membership, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: School.maximum(:id).to_i + 10_000,
      classroom_ids: []
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(teacher.reload.school).to eq(school)
    expect(teacher.classroom_memberships.teacher.exists?(classroom: classroom)).to eq(true)
  end

  it "allows a different-school classroom without changing or deleting memberships" do
    classroom = create(:classroom, school: other_school, grade: 4)
    create(:school_membership, user: teacher, school: school)
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: school.id,
      classroom_ids: [classroom.id]
    }

    expect(response).to redirect_to(classrooms_path)
    expect(teacher.reload.school).to eq(school)
    expect(teacher.classroom_memberships.teacher.exists?(classroom: classroom)).to eq(true)

    get classrooms_path
    expect(response.body).not_to include("학교 소속 확인 필요")
  end

  it "does not warn when a teacher without a school belongs to a school classroom" do
    classroom = create(:classroom, school: school)
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in admin

    get classrooms_path

    expect(response.body).to include("학교 미지정")
    expect(response.body).not_to include("학교 소속 확인 필요")
    expect(teacher.reload.school_membership).to be_nil
  end

  it "shows sorted unique grades and does not warn for matching or schoolless classrooms" do
    matching_classroom = create(:classroom, school: school, grade: 4, name: "4학년 1반")
    duplicate_grade_classroom = create(:classroom, school: school, grade: 4, name: "4학년 2반")
    other_grade_classroom = create(:classroom, school: school, grade: 3, name: "3학년 1반")
    schoolless_classroom = create(:classroom, school: nil, grade: nil, name: "미지정반")
    create(:school_membership, user: teacher, school: school)
    [matching_classroom, duplicate_grade_classroom, other_grade_classroom, schoolless_classroom].each do |classroom|
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    end
    sign_in admin

    get classrooms_path

    expect(response.body).to include("#{school.name} · 3, 4학년")
    expect(response.body).not_to include("학교 소속 확인 필요")
  end

  it "shows unspecified school and grade for an unassigned teacher" do
    teacher
    sign_in admin

    get classrooms_path

    expect(response.body).to include("학교 미지정 · 학년 미지정")
  end

  it "keeps the standalone validation fallback in the application layout" do
    sign_in admin

    post admin_teachers_path, params: {
      user: valid_teacher_params.merge(name: ""),
      school_id: school.id
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("<!DOCTYPE html>")
    expect(response.body).to include("교실로 돌아가기")
  end

  def valid_teacher_params
    {
      name: "새 교사",
      email: "new-school-teacher@example.com",
      password: "password123",
      gender: "female",
      avatar_key: "teacherF01"
    }
  end
end
