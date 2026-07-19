require "rails_helper"

RSpec.describe "School settings", type: :request do
  let(:school) { create(:school, name: "기존 학교") }
  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:school_membership, :manager, school: school, user: create(:user, :teacher, name: "현재 관리자")).user }
  let(:member) { create(:school_membership, school: school, user: create(:user, :teacher, name: "관리자 후보")).user }

  it "renders school name, managers, and only same-school candidates in the modal" do
    current_manager = manager
    candidate = member
    other_teacher = create(:school_membership, school: create(:school), user: create(:user, :teacher, name: "다른 학교 교사")).user
    unassigned_teacher = create(:user, :teacher, name: "미소속 교사")
    student = create(:user, :student, name: "학생")
    sign_in admin

    get edit_school_path(school), headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<turbo-frame id="modal"', "학교 설정", school.name, current_manager.name, candidate.name)
    expect(response.body).not_to include(other_teacher.name, unassigned_teacher.name, student.name)
  end

  it "updates the name and refreshes the overview for Turbo" do
    manager
    sign_in admin

    patch school_path(school),
      params: { school: { name: "변경 학교", manager_id: member.id } },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      'turbo-stream action="replace" target="school_overview"',
      'turbo-stream action="update" target="modal"',
      "변경 학교"
    )
    expect(school.reload.name).to eq("변경 학교")
    expect(member.reload.school_membership).to be_member
  end

  it "redirects the HTML update to the school" do
    sign_in admin

    patch school_path(school), params: { school: { name: "HTML 변경" } }

    expect(response).to redirect_to(school_path(school))
    expect(school.reload.name).to eq("HTML 변경")
  end

  it "renders validation failures in the modal with 422" do
    sign_in admin

    patch school_path(school),
      params: { school: { name: "" } },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(school.reload.name).to eq("기존 학교")
  end

  it "blocks managers, members, and guests" do
    [manager, member].each do |actor|
      sign_in actor
      get edit_school_path(school)
      expect(response).to redirect_to(root_path)

      patch school_path(school), params: { school: { name: "차단" } }
      expect(response).to redirect_to(root_path)
    end

    sign_out :user
    get edit_school_path(school)
    expect(response).to redirect_to(new_user_session_path)
  end
end
