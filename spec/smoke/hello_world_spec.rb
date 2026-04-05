require "rails_helper"

RSpec.describe "Hello world", type: :model do
  it "runs a basic example" do
    expect("hello").to eq("hello")
  end

  it "loads shoulda-matchers" do
    expect(User.new).to validate_presence_of(:name)
  end
end
