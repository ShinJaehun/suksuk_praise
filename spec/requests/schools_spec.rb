require "rails_helper"

RSpec.describe "School workspaces", type: :request do
  let!(:school) { create(:school, name: "새싹초등학교") }
  let!(:other_school) { create(:school, name: "다른초등학교") }
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user, :teacher) }
  let(:manager) { create(:user, :teacher) }

  before do
    create(:school_membership, school: school, user: member)
    create(:school_membership, :manager, school: school, user: manager)
  end

  it "allows an admin to view every school workspace and manage closures" do
    sign_in admin

    get school_path(other_school)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(other_school.name)
    expect(response.body).to include(new_school_school_closure_path(other_school))
  end

  it "allows members and managers to view only their school" do
    [member, manager].each do |teacher|
      sign_in teacher
      get school_path(school)
      expect(response).to have_http_status(:ok)

      get school_path(other_school)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "hides management actions from a member and shows them to a manager" do
    closure = create(:school_closure, school: school)

    sign_in member
    get school_path(school)
    expect(response.body).not_to include(new_school_school_closure_path(school))
    expect(response.body).not_to include(edit_school_school_closure_path(school, closure))

    sign_in manager
    get school_path(school)
    expect(response.body).to include(new_school_school_closure_path(school))
    expect(response.body).to include(edit_school_school_closure_path(school, closure))
    expect(response.body).not_to include("translation missing")
  end

  it "rejects an unassigned teacher and a student" do
    [create(:user, :teacher), create(:user, :student)].each do |user|
      sign_in user
      get school_path(school)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "exposes appropriate workspace links from the classrooms hub" do
    sign_in admin
    get classrooms_path
    expect(response.body).to include(school_path(school))

    sign_in member
    get classrooms_path
    expect(response.body).to include(school_path(school))
    expect(response.body).not_to include(school_path(other_school))
    expect(response.body).not_to include("translation missing")
  end
end
