require "rails_helper"

RSpec.describe "FactoryBot smoke", type: :model do
  it "builds a valid user factory" do
    user = build(:user)

    expect(user).to be_valid
    expect(user.role).to eq("student")
  end
end
