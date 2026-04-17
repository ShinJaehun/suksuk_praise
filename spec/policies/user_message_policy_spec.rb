require "rails_helper"

RSpec.describe UserMessagePolicy do
  let(:classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }
  let(:other_teacher) { create(:user, :teacher) }
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user, :student) }
  let(:other_student) { create(:user, :student) }

  before do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    create(:classroom_membership, user: student, classroom: classroom, role: "student")
    create(:classroom_membership, user: other_student, classroom: create(:classroom), role: "student")
  end

  describe "#create?" do
    it "allows a teacher to send a managed root message" do
      message = build(:user_message, classroom: classroom, sender: teacher, recipient: student)

      expect(described_class.new(teacher, message).create?).to eq(true)
    end

    it "allows an admin to send a root message to a student" do
      message = build(:user_message, classroom: classroom, sender: admin, recipient: student)

      expect(described_class.new(admin, message).create?).to eq(true)
    end

    it "rejects a teacher outside the classroom" do
      message = build(:user_message, classroom: classroom, sender: other_teacher, recipient: student)

      expect(described_class.new(other_teacher, message).create?).to eq(false)
    end

    it "allows a student to reply to an existing teacher root" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "원글")
      reply = build(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: root, body: "학생 답장")

      expect(described_class.new(student, reply).create?).to eq(true)
    end

    it "allows a student to reply to an existing admin root" do
      root = create(:user_message, classroom: classroom, sender: admin, recipient: student, body: "관리자 메시지")
      reply = build(:user_message, classroom: classroom, sender: student, recipient: admin, parent_message: root, body: "학생 답장")

      expect(described_class.new(student, reply).create?).to eq(true)
    end

    it "rejects a student starting a new conversation" do
      reply = build(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "먼저 보냄")

      expect(described_class.new(student, reply).create?).to eq(false)
    end

    it "rejects a student for another student's root thread" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "원글")
      reply = build(:user_message, classroom: classroom, sender: other_student, recipient: teacher, parent_message: root, body: "남의 대화")

      expect(described_class.new(other_student, reply).create?).to eq(false)
    end

    it "rejects a reply to another reply" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "원글")
      reply = create(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: root, body: "첫 답글")
      nested_reply = build(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: reply, body: "답글의 답글")

      expect(described_class.new(student, nested_reply).create?).to eq(false)
    end
  end
end
