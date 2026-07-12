require "rails_helper"

RSpec.describe "Role landing pages", type: :request do
  it "routes an admin to schools" do
    sign_in create(:user, :admin)
    get root_path
    expect(response).to redirect_to(schools_path)
  end

  it "routes a single-school manager to the school dashboard" do
    manager = create(:user, :teacher)
    membership = create(:school_membership, :manager, user: manager)
    sign_in manager
    get root_path
    expect(response).to redirect_to(school_path(membership.school))
  end

  it "routes a regular teacher to classrooms" do
    teacher = create(:user, :teacher)
    create(:school_membership, user: teacher)
    sign_in teacher
    get root_path
    expect(response).to redirect_to(classrooms_path)
  end

  it "keeps the student landing behavior" do
    student = create(:user, :student)
    sign_in student
    get root_path
    expect(response).to redirect_to(user_path(student))
  end
end
