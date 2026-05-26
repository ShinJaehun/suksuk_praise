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

    it "rejects a teacher root message when classroom messages are disabled" do
      classroom.update!(message_policy: "disabled")
      message = build(:user_message, classroom: classroom, sender: teacher, recipient: student)

      expect(described_class.new(teacher, message).create?).to eq(false)
    end

    it "allows an admin to send a root message to a student" do
      message = build(:user_message, classroom: classroom, sender: admin, recipient: student)

      expect(described_class.new(admin, message).create?).to eq(true)
    end

    it "rejects an admin root message when classroom messages are disabled" do
      classroom.update!(message_policy: "disabled")
      message = build(:user_message, classroom: classroom, sender: admin, recipient: student)

      expect(described_class.new(admin, message).create?).to eq(false)
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

    it "rejects a student reply when classroom messages are disabled" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "원글")
      classroom.update!(message_policy: "disabled")
      reply = build(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: root, body: "학생 답장")

      expect(described_class.new(student, reply).create?).to eq(false)
    end

    it "allows a student to reply to an existing admin root" do
      root = create(:user_message, classroom: classroom, sender: admin, recipient: student, body: "관리자 메시지")
      reply = build(:user_message, classroom: classroom, sender: student, recipient: admin, parent_message: root, body: "학생 답장")

      expect(described_class.new(student, reply).create?).to eq(true)
    end

    it "rejects a student starting a new conversation when policy is replies only" do
      reply = build(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "먼저 보냄")

      expect(described_class.new(student, reply).create?).to eq(false)
    end

    it "allows a student root message when classroom policy is student initiated" do
      classroom.update!(message_policy: "student_initiated")
      message = build(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "먼저 보냄")

      expect(described_class.new(student, message).create?).to eq(true)
    end

    it "allows a student to reply to an existing student-started root when policy changes to replies only" do
      classroom.update!(message_policy: "student_initiated")
      root = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "학생 원글")
      classroom.update!(message_policy: "replies_only")
      reply = build(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: root, body: "추가 답장")

      expect(described_class.new(student, reply).create?).to eq(true)
    end

    it "allows a teacher to reply to a managed student's teacher-started root" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "교사 원글")
      reply = build(:user_message, classroom: classroom, sender: teacher, recipient: student, parent_message: root, body: "교사 답장")

      expect(described_class.new(teacher, reply).create?).to eq(true)
    end

    it "rejects a teacher replying to a thread outside the teacher's classrooms" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "교사 원글")
      reply = build(:user_message, classroom: classroom, sender: other_teacher, recipient: student, parent_message: root, body: "외부 교사 답장")

      expect(described_class.new(other_teacher, reply).create?).to eq(false)
    end

    it "allows an admin to reply to a student thread" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "교사 원글")
      reply = build(:user_message, classroom: classroom, sender: admin, recipient: student, parent_message: root, body: "관리자 답장")

      expect(described_class.new(admin, reply).create?).to eq(true)
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
