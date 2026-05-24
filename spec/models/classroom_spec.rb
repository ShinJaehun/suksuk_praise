require "rails_helper"

RSpec.describe Classroom, type: :model do
  it "disables student initiated messages by default" do
    classroom = described_class.create!(name: "기본 교실")

    expect(classroom.student_initiated_messages_enabled?).to eq(false)
  end

  it "generates a student login token" do
    classroom = described_class.create!(name: "토큰 교실")

    expect(classroom.student_login_token).to be_present
  end
end
