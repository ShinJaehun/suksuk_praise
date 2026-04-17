require "rails_helper"

RSpec.describe UserMessage, type: :model do
  let(:classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user, :student) }

  before do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    create(:classroom_membership, user: student, classroom: classroom, role: "student")
  end

  it "is valid for a teacher sending a root message to a student" do
    message = described_class.new(
      classroom: classroom,
      sender: teacher,
      recipient: student,
      body: "메시지"
    )

    expect(message).to be_valid
  end

  it "is valid for an admin sending a root message to a student in the classroom context" do
    message = described_class.new(
      classroom: classroom,
      sender: admin,
      recipient: student,
      body: "관리자 메시지"
    )

    expect(message).to be_valid
  end

  it "rejects blank body" do
    message = described_class.new(
      classroom: classroom,
      sender: teacher,
      recipient: student,
      body: ""
    )

    expect(message).not_to be_valid
  end

  it "rejects a student root message" do
    message = described_class.new(
      classroom: classroom,
      sender: student,
      recipient: teacher,
      body: "학생 원글"
    )

    expect(message).not_to be_valid
  end

  it "allows a student reply under a teacher root message" do
    root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "원글")
    reply = described_class.new(
      classroom: classroom,
      sender: student,
      recipient: teacher,
      parent_message: root,
      body: "답글"
    )

    expect(reply).to be_valid
  end

  it "rejects a student reply without parent_message" do
    reply = described_class.new(
      classroom: classroom,
      sender: student,
      recipient: teacher,
      body: "답글"
    )

    expect(reply).not_to be_valid
  end

  it "rejects a reply to another reply" do
    root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "원글")
    reply = create(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: root, body: "첫 답글")
    nested_reply = described_class.new(
      classroom: classroom,
      sender: student,
      recipient: teacher,
      parent_message: reply,
      body: "중첩 답글"
    )

    expect(nested_reply).not_to be_valid
  end

  it "rejects teacher/admin to teacher/admin messages" do
    message = described_class.new(
      classroom: classroom,
      sender: teacher,
      recipient: admin,
      body: "교사 관리자 메시지"
    )

    expect(message).not_to be_valid
  end

  it "rejects a teacher outside the classroom context" do
    other_teacher = create(:user, :teacher)

    message = described_class.new(
      classroom: classroom,
      sender: other_teacher,
      recipient: student,
      body: "다른 교실 교사"
    )

    expect(message).not_to be_valid
  end
end
