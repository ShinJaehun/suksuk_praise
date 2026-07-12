require "rails_helper"

RSpec.describe "Admin school managers", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:school) { create(:school) }
  let(:teacher) { create(:user, :teacher) }

  it "promotes an existing member and creates a manager membership when absent" do
    membership = create(:school_membership, school: school, user: teacher)
    sign_in admin

    post admin_school_school_managers_path(school), params: { user_id: teacher.id }
    expect(membership.reload).to be_manager

    other_teacher = create(:user, :teacher)
    post admin_school_school_managers_path(school), params: { user_id: other_teacher.id }
    expect(other_teacher.reload.school_membership).to be_manager
  end

  it "demotes a manager without deleting the membership" do
    membership = create(:school_membership, :manager, school: school, user: teacher)
    sign_in admin

    delete admin_school_manager_path(school, teacher)

    expect(membership.reload).to be_member
  end

  it "rejects manager and member requests and student targets" do
    manager = create(:user, :teacher)
    member = create(:user, :teacher)
    create(:school_membership, :manager, school: school, user: manager)
    create(:school_membership, school: school, user: member)

    [manager, member].each do |actor|
      sign_in actor
      post admin_school_school_managers_path(school), params: { user_id: teacher.id }
      expect(teacher.reload.school_membership).to be_nil
    end

    sign_in admin
    post admin_school_school_managers_path(school), params: { user_id: create(:user, :student).id }
    expect(response).to have_http_status(:not_found)
  end

  it "does not change a membership belonging to another school" do
    membership = create(:school_membership, school: create(:school), user: teacher)
    sign_in admin

    post admin_school_school_managers_path(school), params: { user_id: teacher.id }

    expect(membership.reload).to have_attributes(role: "member", school_id: membership.school_id)
  end

  it "shows only unassigned and same-school member teachers as candidates" do
    unassigned = teacher
    same_school_member = create(:school_membership, school: school)
    same_school_manager = create(:school_membership, :manager, school: school)
    other_school_teacher = create(:school_membership, school: create(:school))
    sign_in admin

    get school_path(school)

    expect(response.body).to include(unassigned.name, same_school_member.user.name)
    expect(response.body).not_to include(%(value="#{same_school_manager.user.id}"))
    expect(response.body).not_to include(%(value="#{other_school_teacher.user.id}"))
  end
end
