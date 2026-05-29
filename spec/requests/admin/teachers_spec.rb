require "rails_helper"

RSpec.describe "Admin teachers", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: "담당 교사") }

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
  end

  it "targets modal form submissions to the top frame" do
    sign_in admin

    get new_admin_teacher_path, headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<turbo-frame id="modal"')
    expect(response.body).to include("새 교사 추가")
    expect(response.body).to include('data-turbo-frame="_top"')
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
    expect(response.body).to include("담임 교실 배정")
    expect(response.body).to include("교실로 돌아가기")
    expect(response.body).not_to include('data-turbo-frame="_top"')
    expect(response.body).not_to include("bg-black/50")
    expect(response.body).not_to include('data-action="modal#close"')
  end

  it "renders teacher assignment in the modal frame" do
    sign_in admin

    get edit_admin_teacher_path(teacher), headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<turbo-frame id="modal"')
    expect(response.body).to include("담임 교실 배정")
    expect(response.body).to include('data-turbo-frame="_top"')
  end
end
