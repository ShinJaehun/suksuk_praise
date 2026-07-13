require "rails_helper"

RSpec.describe "School closure management", type: :request do
  let!(:school) { create(:school) }
  let!(:other_school) { create(:school) }
  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:user, :teacher) }
  let(:member) { create(:user, :teacher) }

  before do
    create(:school_membership, :manager, school: school, user: manager)
    create(:school_membership, school: school, user: member)
  end

  it "allows an admin to create a closure for any school" do
    sign_in admin

    expect do
      post school_school_closures_path(other_school), params: { school_closure: valid_params }
    end.to change(other_school.school_closures, :count).by(1)

    expect(response).to redirect_to(school_path(other_school))
  end

  it "allows a manager to create, update, and delete a closure for their school" do
    sign_in manager

    post school_school_closures_path(school), params: { school_closure: valid_params }
    closure = school.school_closures.find_by!(name: "여름방학")
    expect(response).to redirect_to(school_path(school))

    patch school_school_closure_path(school, closure), params: { school_closure: valid_params.merge(name: "겨울방학") }
    expect(closure.reload.name).to eq("겨울방학")

    expect do
      delete school_school_closure_path(school, closure, month: "2026-07")
    end.to change(school.school_closures, :count).by(-1)
    expect(response).to redirect_to(school_path(school, month: "2026-07"))
  end

  it "prevents a member from creating a closure" do
    sign_in member

    expect do
      post school_school_closures_path(school), params: { school_closure: valid_params }
    end.not_to change(SchoolClosure, :count)

    expect(response).to redirect_to(root_path)
  end

  it "prevents a manager from creating a closure for another school" do
    sign_in manager

    expect do
      post school_school_closures_path(other_school), params: { school_closure: valid_params }
    end.not_to change(SchoolClosure, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "does not expose a closure through another school's nested URL" do
    closure = create(:school_closure, school: other_school)
    sign_in admin

    get edit_school_school_closure_path(school, closure)

    expect(response).to have_http_status(:not_found)
  end

  it "returns 422 without changing data when validation fails" do
    closure = create(:school_closure, school: school, name: "기존 휴무")
    sign_in manager

    expect do
      patch school_school_closure_path(school, closure), params: { school_closure: valid_params.merge(name: "", ends_on: "2026-07-01") }
    end.not_to change { closure.reload.attributes.slice("name", "starts_on", "ends_on") }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include("translation missing")
  end

  it "renders the calendar month with errors when inline create validation fails" do
    sign_in manager

    expect do
      post school_school_closures_path(school, month: "2026-08"),
        params: {
          return_to_calendar: "1",
          school_closure: valid_params.merge(starts_on: "2026-08-10", ends_on: "2026-08-09")
        }
    end.not_to change(SchoolClosure, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("2026년 8월")
    expect(response.body).to include("입력 내용을 확인해 주세요.")
    expect(response.body).not_to include("translation missing")
  end

  it "deletes only the nested closure" do
    closure = create(:school_closure, school: school)
    other_closure = create(:school_closure, school: other_school)
    sign_in manager

    delete school_school_closure_path(school, closure)

    expect(SchoolClosure.exists?(closure.id)).to eq(false)
    expect(SchoolClosure.exists?(other_closure.id)).to eq(true)
  end

  def valid_params
    { name: "여름방학", starts_on: "2026-07-20", ends_on: "2026-08-14" }
  end
end
