require "rails_helper"

RSpec.describe "Admin teachers", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: "담당 교사") }

  it "redirects the retired teacher index to classrooms" do
    sign_in admin

    get "/admin/teachers"

    expect(response).to redirect_to("/classrooms")
  end

  it "opens the new teacher form from classrooms in the modal frame" do
    sign_in admin

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(new_admin_teacher_path)
    expect(response.body).to include('data-turbo-frame="modal"')
    expect(response.body).to include("새 선생님 추가")
  end

  it "keeps the new teacher page fallback" do
    sign_in admin

    get new_admin_teacher_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("새 교사 추가")
    expect(response.body).to include("교실로 돌아가기")
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
    expect(response.body).to include("새 교사 추가")
    expect(response.body).to include('data-turbo-frame="_top"')
    expect(response.body).not_to include("<!DOCTYPE html>")
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

  it "opens teacher assignment links from classrooms in the modal frame" do
    teacher
    sign_in admin

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_teacher_path(teacher))
    expect(response.body).to include('data-turbo-frame="modal"')
  end

  it "keeps the teacher assignment page fallback" do
    sign_in admin

    get edit_admin_teacher_path(teacher)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("교사 소속 및 담당 교실")
    expect(response.body).to include("교실로 돌아가기")
    expect(response.body).to include('data-turbo-frame="_top"')
  end

  it "renders teacher assignment in the modal frame" do
    sign_in admin

    get edit_admin_teacher_path(teacher), headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include("교사 소속 및 담당 교실")
    expect(response.body).to include('data-turbo-frame="_top"')
    expect(response.body).not_to include("<!DOCTYPE html>")
    expect(response.body).to include("교실로 돌아가기")
  end
end
