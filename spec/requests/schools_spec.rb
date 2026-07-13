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

  it "shows every school in the admin index" do
    sign_in admin

    get schools_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(school.name, other_school.name)
    expect(response.body).not_to include("translation missing")
  end

  it "redirects a member or manager index to their only school without exposing others" do
    [member, manager].each do |teacher|
      sign_in teacher
      get schools_path
      expect(response).to redirect_to(school_path(school))
      expect(response.body).not_to include(other_school.name)
    end
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

  it "shows school classrooms and teachers while limiting manager controls to admin" do
    classroom = create(:classroom, school: school)
    create(:classroom_membership, classroom: classroom, user: member, role: :teacher)

    [member, manager].each do |teacher|
      sign_in teacher
      get school_path(school)
      expect(response.body).to include(classroom.name, member.name)
      expect(response.body).not_to include(admin_school_school_managers_path(school))
    end

    sign_in admin
    get school_path(school)
    expect(response.body).to include(admin_school_school_managers_path(school))
  end

  it "links classrooms only when the viewer can open them" do
    assigned_classroom = create(:classroom, school: school, name: "담당 학급")
    unassigned_classroom = create(:classroom, school: school, name: "미담당 학급")
    create(:classroom_membership, classroom: assigned_classroom, user: member, role: :teacher)

    sign_in member
    get school_path(school)
    expect(response.body).to include(assigned_classroom.name, unassigned_classroom.name)
    expect(response.body).to include(classroom_path(assigned_classroom))
    expect(response.body).not_to include(classroom_path(unassigned_classroom))

    sign_in manager
    get school_path(school)
    expect(response.body).to include(classroom_path(assigned_classroom), classroom_path(unassigned_classroom))

    sign_in admin
    get school_path(school)
    expect(response.body).to include(classroom_path(assigned_classroom), classroom_path(unassigned_classroom))
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

  it "shows a member their school and upcoming closure summary in the classrooms hub" do
    closure = create(:school_closure, school: school, name: "재량휴업일", starts_on: 1.day.from_now.to_date, ends_on: 1.day.from_now.to_date)
    sign_in member

    get classrooms_path

    expect(response.body).to include(school_path(school), school.name, closure.name)
  end
end
