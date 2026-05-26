require "rails_helper"

RSpec.describe Classroom, type: :model do
  it "uses replies only messages by default" do
    classroom = described_class.create!(name: "기본 교실")

    expect(classroom.message_policy).to eq("replies_only")
    expect(classroom.student_messages_enabled?).to eq(true)
    expect(classroom.student_can_start_messages?).to eq(false)
  end

  it "supports disabled message policy" do
    classroom = described_class.create!(name: "비활성 교실", message_policy: "disabled")

    expect(classroom.messages_disabled?).to eq(true)
    expect(classroom.student_messages_enabled?).to eq(false)
    expect(classroom.student_can_start_messages?).to eq(false)
  end

  it "supports student initiated message policy" do
    classroom = described_class.create!(name: "학생 시작 교실", message_policy: "student_initiated")

    expect(classroom.student_messages_enabled?).to eq(true)
    expect(classroom.student_can_start_messages?).to eq(true)
  end

  it "generates a student login token" do
    classroom = described_class.create!(name: "토큰 교실")

    expect(classroom.student_login_token).to be_present
  end
end
