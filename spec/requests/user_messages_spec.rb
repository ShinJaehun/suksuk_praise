require "rails_helper"

RSpec.describe "User messages", type: :request do
  describe "teacher/admin root messages and student replies" do
    let(:student) { create(:user, :student, password: "password123") }
    let(:teacher) { create(:user, :teacher) }
    let(:other_teacher) { create(:user, :teacher) }
    let(:admin) { create(:user, :admin) }
    let(:classroom) { create(:classroom) }
    let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }

    before do
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      create(:classroom_membership, user: other_teacher, classroom: classroom, role: "teacher")
    end

    it "allows a teacher to send a root message from the managed student page with turbo stream" do
      sign_in teacher

      expect {
        post classroom_student_messages_path(classroom, student),
             params: { user_message: { body: "오늘 발표 잘했어." } },
             headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(UserMessage.last.sender).to eq(teacher)
      expect(UserMessage.last.recipient).to eq(student)
      expect(UserMessage.last.parent_message_id).to be_nil
    end

    it "allows an admin to send a root message to a student" do
      sign_in admin

      expect {
        post classroom_student_messages_path(classroom, student),
             params: { user_message: { body: "관리자 공지야." } },
             headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(UserMessage.last.sender).to eq(admin)
      expect(UserMessage.last.parent_message_id).to be_nil
    end

    it "shows a teacher root and student replies in the same thread card" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "선생님 메시지")
      create(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: root, body: "학생 댓글")
      sign_in student

      get user_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("선생님 메시지")
      expect(response.body).to include("학생 댓글")
      expect(response.body).to include("나")
      expect(response.body).to include("reply_to_message_id")
    end

    it "allows a student to reply under a teacher root with turbo stream" do
      incoming = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "질문 있어?")
      sign_in student

      expect {
        post user_messages_path(student),
             params: {
               reply_to_message_id: incoming.id,
               user_message: { body: "네, 있어요." }
             },
             headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(UserMessage.last.sender).to eq(student)
      expect(UserMessage.last.recipient).to eq(teacher)
      expect(UserMessage.last.parent_message).to eq(incoming)
    end

    it "allows a student to reply under an admin root" do
      incoming = create(:user_message, classroom: classroom, sender: admin, recipient: student, body: "관리자 확인 부탁해.")
      sign_in student

      expect {
        post user_messages_path(student),
             params: {
               reply_to_message_id: incoming.id,
               user_message: { body: "확인했습니다." }
             },
             headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      expect(UserMessage.last.recipient).to eq(admin)
      expect(UserMessage.last.parent_message).to eq(incoming)
    end

    it "lets a student reply inside each sender's root thread separately" do
      teacher_root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "teacher")
      admin_root = create(:user_message, classroom: classroom, sender: admin, recipient: student, body: "admin")
      sign_in student

      post user_messages_path(student), params: {
        reply_to_message_id: teacher_root.id,
        user_message: { body: "선생님께 답장" }
      }
      post user_messages_path(student), params: {
        reply_to_message_id: admin_root.id,
        user_message: { body: "관리자께 답장" }
      }

      replies = UserMessage.where(sender: student).order(:created_at)
      expect(replies.pluck(:recipient_id)).to eq([teacher.id, admin.id])
      expect(replies.pluck(:parent_message_id)).to eq([teacher_root.id, admin_root.id])
    end

    it "rejects a student from replying to another student's root thread" do
      other_student = create(:user, :student, password: "password123")
      create(:classroom_membership, user: other_student, classroom: classroom, role: "student")
      incoming = create(:user_message, classroom: classroom, sender: teacher, recipient: other_student, body: "다른 학생용")
      sign_in student

      expect {
        post user_messages_path(student), params: {
          reply_to_message_id: incoming.id,
          user_message: { body: "가로채기" }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(user_path(student))
    end

    it "rejects a reply to another reply" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "원글")
      reply = create(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: root, body: "첫 답글")
      sign_in student

      expect {
        post user_messages_path(student), params: {
          reply_to_message_id: reply.id,
          user_message: { body: "답글의 답글 시도" }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(user_path(student))
    end

    it "rejects a teacher from messaging a student outside the classroom" do
      outside_classroom = create(:classroom)
      outside_student = create(:user, :student)
      create(:classroom_membership, user: outside_student, classroom: outside_classroom, role: "student")
      sign_in teacher

      expect {
        post classroom_student_messages_path(outside_classroom, outside_student), params: {
          user_message: { body: "다른 교실 학생" }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(root_path)
    end

    it "re-renders the managed message section with inline errors on turbo failure" do
      sign_in teacher

      expect {
        post classroom_student_messages_path(classroom, student),
             params: { user_message: { body: "" } },
             headers: turbo_headers
      }.not_to change(UserMessage, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("message_section")
    end

    it "re-renders the matching reply form with inline errors on turbo failure" do
      incoming = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "질문 있어?")
      sign_in student

      expect {
        post user_messages_path(student),
             params: {
               reply_to_message_id: incoming.id,
               user_message: { body: "" }
             },
             headers: turbo_headers
      }.not_to change(UserMessage, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("reply_to_message_id")
      expect(response.body).to include("message_section")
    end
  end
end
