require "rails_helper"

RSpec.describe "Authorization redirects", type: :request do
  let(:school) { create(:school) }
  let(:classroom) { create(:classroom, school: school) }
  let(:teacher) { create(:user, :teacher) }

  it "redirects a teacher with no remaining classrooms to the classrooms index" do
    membership = create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    sign_in teacher

    get classroom_path(classroom)
    expect(response).to have_http_status(:ok)

    membership.destroy!
    get classroom_path(classroom), headers: { "HTTP_REFERER" => classroom_url(classroom) }

    expect(response).to redirect_to(root_path)

    follow_redirect!

    expect(response).to redirect_to(classrooms_path)
  end

  it "redirects a teacher to their one remaining classroom" do
    membership = create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    remaining_classroom = create(:classroom, school: school)
    create(:classroom_membership, classroom: remaining_classroom, user: teacher, role: "teacher")
    sign_in teacher

    get classroom_path(classroom)
    expect(response).to have_http_status(:ok)

    membership.destroy!
    get classroom_path(classroom), headers: { "HTTP_REFERER" => classroom_url(classroom) }

    expect(response).to redirect_to(root_path)

    follow_redirect!

    expect(response).to redirect_to(classroom_path(remaining_classroom))
  end
end
