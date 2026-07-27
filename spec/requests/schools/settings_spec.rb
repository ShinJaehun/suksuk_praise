require "rails_helper"

RSpec.describe "School settings", type: :request do
  let(:school) { create(:school, name: "기존 학교") }
  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:school_membership, :manager, school: school, user: create(:user, :teacher, name: "현재 관리자")).user }
  let(:member) { create(:school_membership, school: school, user: create(:user, :teacher, name: "관리자 후보")).user }

  it "renders school settings and color choices for a global admin" do
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

    document = Nokogiri::HTML(response.body)
    color_inputs = document.css('input[type="radio"][name="school[color_key]"]')

    expect(color_inputs.map { |input| input["value"] }).to eq(School::COLOR_KEYS)
    expect(color_inputs.find { |input| input["checked"] }&.[]("value")).to eq(school.color_key)
    expect(response.body).to include("색상 저장", "하늘색", "초록색", "보라색", "노란색", "분홍색", "청록색", "남색", "주황색")
    expect(response.body).not_to include("Translation missing")
  end

  it "excludes inactive teachers from manager candidates" do
    active_candidate = member
    inactive_candidate = create(
      :school_membership,
      school: school,
      user: create(:user, :teacher, name: "비활성 후보", active: false)
    ).user
    sign_in admin

    get edit_school_path(school)

    expect(response.body).to include(active_candidate.name)
    expect(response.body).not_to include(inactive_candidate.name)
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

  it "allows a global admin to update the school color" do
    sign_in admin

    patch school_path(school), params: { school: { color_key: "violet" } }

    expect(response).to redirect_to(school_path(school))
    expect(school.reload.color_key).to eq("violet")
  end

  it "rejects an invalid school color and rerenders the settings form" do
    original_color_key = school.color_key
    sign_in admin

    patch school_path(school), params: { school: { color_key: "red" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("학교 구분 색상", 'name="school[color_key]"')
    expect(Nokogiri::HTML(response.body).at_css("p.text-rose-600")&.text).to be_present
    expect(school.reload.color_key).to eq(original_color_key)
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
