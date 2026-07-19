require "rails_helper"

RSpec.describe "School overview", type: :request do
  let(:school) { create(:school, name: "아라초등학교") }
  let(:manager) { create(:school_membership, :manager, school: school, user: create(:user, :teacher, name: "학교 관리자")).user }

  it "shows only school summary and settings entry to an admin" do
    classroom = create(:classroom, school: school, name: "상세 학급 이름")
    teacher = create(:school_membership, school: school, user: create(:user, :teacher, name: "상세 교사 이름")).user
    school_manager = manager
    sign_in create(:user, :admin)

    get school_path(school)

    document = Nokogiri::HTML(response.body)
    overview = document.at_css("turbo-frame#school_overview")
    expect(response).to have_http_status(:ok)
    expect(overview.text).to include(school.name, "소속 교실", "1개", "소속 교사", "2명", school_manager.name)
    expect(overview.at_css(%(a[href="#{classrooms_path}"]))).to be_present
    expect(overview.text).to include("교실 목록으로")
    expect(overview.text).not_to include("교실 목록으로 돌아가기")
    expect(overview.at_css(%(a[href="#{edit_school_path(school)}"][data-turbo-frame="modal"]))).to be_present
    expect(response.body).to include("학교 휴일")
    expect(response.body).not_to include(classroom.name, teacher.name)
    expect(overview.at_css(%(a[href="#{new_classroom_path}"]))).to be_nil
    expect(overview.at_css(%(a[href="#{new_school_teacher_path(school)}"]))).to be_nil
  end

  it "hides school settings from the school manager while showing the manager name" do
    school_manager = manager
    sign_in school_manager

    get school_path(school)

    overview = Nokogiri::HTML(response.body).at_css("turbo-frame#school_overview")
    expect(response).to have_http_status(:ok)
    expect(overview.text).to include(school.name, school_manager.name, "교실 목록으로")
    expect(overview.at_css(%(a[href="#{edit_school_path(school)}"]))).to be_nil
  end

  it "hides school settings from a member teacher while showing manager names" do
    school_manager = manager
    member = create(:school_membership, school: school, user: create(:user, :teacher)).user
    sign_in member

    get school_path(school)

    overview = Nokogiri::HTML(response.body).at_css("turbo-frame#school_overview")
    expect(response).to have_http_status(:ok)
    expect(overview.text).to include(school_manager.name)
    expect(overview.at_css(%(a[href="#{edit_school_path(school)}"]))).to be_nil
  end
end
