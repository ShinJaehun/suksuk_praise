require "rails_helper"

RSpec.describe "School management hub", type: :request do
  let(:school) { create(:school) }

  it "shows the school teacher management link to an admin" do
    classroom = create(:classroom, school: school)
    sign_in create(:user, :admin)

    get school_path(school)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(href="#{school_teachers_path(school)}"))
    expect(response.body).to include(%(href="#{new_classroom_path}"), %(href="#{edit_classroom_path(classroom)}"))
  end

  it "shows the school teacher management link to that school's manager" do
    classroom = create(:classroom, school: school)
    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    get school_path(school)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(href="#{school_teachers_path(school)}"))
    expect(response.body).to include(%(href="#{new_classroom_path}"), %(href="#{edit_classroom_path(classroom)}"))
  end

  it "does not show the school teacher management link to a member teacher" do
    member = create(:user, :teacher)
    create(:school_membership, school: school, user: member)
    sign_in member

    get school_path(school)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(%(href="#{school_teachers_path(school)}"))
  end
end
