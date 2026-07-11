require "rails_helper"

RSpec.describe "Classroom organization settings", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher) }
  let(:school) { create(:school, name: "새싹초등학교") }

  it "shows school and grade fields only to an admin" do
    sign_in admin
    get new_classroom_path

    expect(response.body).to include('name="classroom[school_id]"')
    expect(response.body).to include('name="classroom[grade]"')
    expect(response.body).to include("학교 선택")
    expect(response.body).to include("학년 선택")

    sign_in teacher
    get new_classroom_path

    expect(response.body).not_to include('name="classroom[school_id]"')
    expect(response.body).not_to include('name="classroom[grade]"')
  end

  it "allows an admin to create a classroom with a school and grade" do
    sign_in admin

    post classrooms_path, params: {
      classroom: {
        name: "1학년 1반",
        school_id: school.id,
        grade: 1,
        teacher_ids: [teacher.id]
      }
    }

    classroom = Classroom.find_by!(name: "1학년 1반")
    expect(response).to redirect_to(classroom_path(classroom))
    expect(classroom.school).to eq(school)
    expect(classroom.grade).to eq(1)
  end

  it "allows an admin to change an existing classroom school and grade" do
    classroom = create(:classroom, school: nil, grade: nil)
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    sign_in admin

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(school_id: school.id, grade: 6)
    }

    expect(response).to redirect_to(classroom_path(classroom))
    persisted_classroom = Classroom.find(classroom.id)
    expect(persisted_classroom.school_id).to eq(school.id)
    expect(persisted_classroom.grade).to eq(6)
    expect(classroom.reload.school_id).to eq(school.id)
    expect(classroom.grade).to eq(6)
    expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(true)

    follow_redirect!
    expect(response.body).to include("교실 설정을 저장했습니다.")
  end

  it "ignores school and grade params submitted by a teacher" do
    original_school = create(:school)
    other_school = create(:school)
    classroom = create(:classroom, school: original_school, grade: 3)
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    sign_in teacher

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(school_id: other_school.id, grade: 5)
    }

    expect(response).to redirect_to(classroom_path(classroom))
    expect(classroom.reload.school).to eq(original_school)
    expect(classroom.grade).to eq(3)
  end

  it "renders an existing classroom with no school or grade" do
    classroom = create(:classroom, school: nil, grade: nil)
    sign_in admin

    get edit_classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="classroom[school_id]"')
    expect(response.body).to include('name="classroom[grade]"')
  end

  it "shows organization details without repeating the missing label" do
    create(:classroom, name: "미지정 교실", school: nil, grade: nil)
    create(:classroom, name: "지정 교실", school: school, grade: 2)
    sign_in admin

    get classrooms_path

    expect(response.body).to include("새싹초등학교")
    expect(response.body).to include("2학년")
    expect(response.body).to include("미지정")
    expect(response.body).not_to include("미지정 · 미지정")
  end

  it "rejects a grade outside the elementary school range" do
    classroom = create(:classroom, school: nil, grade: nil)
    sign_in admin

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(grade: 7)
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(classroom.reload.grade).to be_nil
    expect(response.body).to include("학년")
  end

  it "safely rejects a school id that does not exist" do
    classroom = create(:classroom, school: nil, grade: nil)
    sign_in admin

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(school_id: School.maximum(:id).to_i + 10_000)
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(classroom.reload.school).to be_nil
    expect(response.body).to include("학교")
  end

  def classroom_update_params(classroom)
    {
      name: classroom.name,
      daily_compliment_king_enabled: classroom.daily_compliment_king_enabled ? "1" : "0",
      weekly_compliment_king_enabled: classroom.weekly_compliment_king_enabled ? "1" : "0",
      monthly_compliment_king_enabled: classroom.monthly_compliment_king_enabled ? "1" : "0",
      message_policy: classroom.message_policy
    }
  end
end
