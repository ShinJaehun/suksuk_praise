require "rails_helper"

RSpec.describe "Admin schools", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher) }
  let(:school) { create(:school, name: "새싹초등학교") }

  it "shows the new school form to an admin" do
    sign_in admin

    get new_admin_school_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("새 학교 등록")
    expect(response.body).to include("교실로 돌아가기")
    expect(response.body).to include('name="school[name]"')
  end

  it "shows schools and classroom counts in the admin classrooms hub" do
    create_list(:classroom, 2, school: school)
    sign_in admin

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("학교 추가")
    expect(response.body).to include(school.name)
    expect(response.body).to include("소속 교실 2개")
    expect(response.body).to include(new_admin_school_path)
    expect(response.body).to include(edit_admin_school_path(school))
    expect(response.body).to include('data-turbo-frame="modal"')
  end

  it "does not show school management in a teacher classrooms hub" do
    sign_in teacher

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("학교 추가")
    expect(response.body).not_to include(new_admin_school_path)
  end

  it "renders the new school form in the common modal frame" do
    sign_in admin

    get new_admin_school_path, headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include('name="school[name]"')
    expect(response.body).not_to include("<!DOCTYPE html>")
    expect(response.body).not_to include('data-turbo-frame="_top"')
  end

  it "renders the edit school form in one modal frame without the application layout" do
    sign_in admin

    get edit_admin_school_path(school), headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include('name="school[name]"')
    expect(response.body).not_to include("<!DOCTYPE html>")
  end

  it "creates a school" do
    sign_in admin

    expect do
      post admin_schools_path, params: { school: { name: "푸른초등학교" } }
    end.to change(School, :count).by(1)

    expect(response).to redirect_to(classrooms_path)
    expect(School.find_by!(name: "푸른초등학교")).to be_present
  end

  it "refreshes the classrooms hub after a successful modal create" do
    sign_in admin

    post admin_schools_path,
      params: { school: { name: "모달초등학교" } },
      headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(response.body).to include('turbo-stream action="refresh"')
    expect(School.find_by!(name: "모달초등학교")).to be_present
  end

  it "keeps blank name validation errors in the modal frame" do
    sign_in admin

    expect do
      post admin_schools_path,
        params: { school: { name: "" } },
        headers: { "Turbo-Frame" => "modal" }
    end.not_to change(School, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include('name="school[name]"')
    expect(response.body).to include("학교 이름을 입력해 주세요.")
    expect(response.body).to include("새 학교 등록")
    expect(response.body).not_to include("<!DOCTYPE html>")
  end

  it "renders blank name validation errors in the standalone fallback" do
    sign_in admin

    post admin_schools_path, params: { school: { name: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("<!DOCTYPE html>")
    expect(response.body).to include("학교 이름을 입력해 주세요.")
    expect(response.body).to include("교실로 돌아가기")
  end

  it "updates a school name" do
    sign_in admin

    patch admin_school_path(school), params: { school: { name: "튼튼초등학교" } }

    expect(response).to redirect_to(classrooms_path)
    expect(school.reload.name).to eq("튼튼초등학교")
  end

  it "keeps update validation errors in the modal frame" do
    sign_in admin

    patch admin_school_path(school),
      params: { school: { name: "" } },
      headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include('name="school[name]"')
    expect(response.body).to include("학교 이름을 입력해 주세요.")
    expect(response.body).not_to include("<!DOCTYPE html>")
    expect(school.reload.name).to eq("새싹초등학교")
  end

  it "renders the same update validation error in the standalone fallback" do
    sign_in admin

    patch admin_school_path(school), params: { school: { name: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("<!DOCTYPE html>")
    expect(response.body).to include("학교 이름을 입력해 주세요.")
    expect(response.body).to include("교실로 돌아가기")
    expect(school.reload.name).to eq("새싹초등학교")
  end

  it "prevents a teacher from accessing or changing schools" do
    sign_in teacher

    get new_admin_school_path
    expect(response).to redirect_to(root_path)

    expect do
      post admin_schools_path, params: { school: { name: "조작 학교" } }
    end.not_to change(School, :count)

    get edit_admin_school_path(school)
    expect(response).to redirect_to(root_path)

    patch admin_school_path(school), params: { school: { name: "조작된 이름" } }
    expect(response).to redirect_to(root_path)
    expect(school.reload.name).to eq("새싹초등학교")
  end

  it "requires authentication" do
    get new_admin_school_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "does not define a destroy route" do
    expect do
      Rails.application.routes.recognize_path("/admin/schools/#{school.id}", method: :delete)
    end.to raise_error(ActionController::RoutingError)
  end
end
