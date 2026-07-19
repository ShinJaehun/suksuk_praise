require "rails_helper"

RSpec.describe "Admin school managers", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:school) { create(:school) }
  let(:teacher) { create(:user, :teacher) }

  it "promotes an existing school member without changing assignments" do
    membership = create(:school_membership, school: school, user: teacher)
    classroom = create(:classroom, school: school)
    classroom_membership = create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
    sign_in admin

    post admin_school_school_managers_path(school), params: { user_id: teacher.id }

    expect(response).to redirect_to(school_path(school))
    expect(membership.reload).to be_manager
    expect(classroom_membership.reload).to be_present
    expect(teacher.reload.school_membership).to eq(membership)
  end

  it "demotes a manager without deleting membership or assignments" do
    membership = create(:school_membership, :manager, school: school, user: teacher)
    classroom_membership = create(:classroom_membership, classroom: create(:classroom, school: school), user: teacher, role: :teacher)
    sign_in admin

    delete admin_school_manager_path(school, teacher)

    expect(response).to redirect_to(school_path(school))
    expect(membership.reload).to be_member
    expect(classroom_membership.reload).to be_present
  end

  it "refreshes the overview and clears the modal for Turbo changes" do
    membership = create(:school_membership, school: school, user: teacher)
    sign_in admin

    post admin_school_school_managers_path(school),
      params: { user_id: teacher.id },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      'turbo-stream action="replace" target="school_overview"',
      'turbo-stream action="update" target="modal"',
      teacher.name
    )
    expect(membership.reload).to be_manager
  end

  it "rejects a school manager actor" do
    actor = create(:school_membership, :manager, school: school).user
    sign_in actor

    post admin_school_school_managers_path(school), params: { user_id: teacher.id }

    expect(response).to redirect_to(root_path)
    expect(teacher.reload.school_membership).to be_nil
  end

  it "rejects a school member actor" do
    actor = create(:school_membership, school: school).user
    sign_in actor

    post admin_school_school_managers_path(school), params: { user_id: teacher.id }

    expect(response).to redirect_to(root_path)
    expect(teacher.reload.school_membership).to be_nil
  end

  it "rejects a student target" do
    target = create(:user, :student)
    sign_in admin

    post admin_school_school_managers_path(school), params: { user_id: target.id }

    expect(response).to have_http_status(:not_found)
    expect(target.reload.school_membership).to be_nil
  end

  it "rejects an unassigned teacher target" do
    target = create(:user, :teacher)
    sign_in admin

    post admin_school_school_managers_path(school), params: { user_id: target.id }

    expect(response).to have_http_status(:not_found)
    expect(target.reload.school_membership).to be_nil
  end

  it "rejects an other-school teacher target without changing its membership" do
    other_school = create(:school)
    membership = create(
      :school_membership,
      school: other_school,
      user: create(:user, :teacher),
      role: :member
    )
    original_school_id = membership.school_id
    target = membership.user
    sign_in admin

    post admin_school_school_managers_path(school), params: { user_id: target.id }

    expect(response).to have_http_status(:not_found)
    expect(target.reload.school_membership).to eq(membership)
    expect(membership.reload).to have_attributes(
      school_id: original_school_id,
      role: "member"
    )
  end
end
