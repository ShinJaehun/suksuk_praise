require "rails_helper"

RSpec.describe "User messages", type: :request do
  include ActionView::RecordIdentifier

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

    it "allows an admin to open the managed student message page" do
      sign_in admin

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(response.body).to include(student.name)
      expect(response.body).to include("한눈에 보기")
      expect(response.body).to include(dashboard_classroom_student_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
      message_navigation = document.at_css(%(a[href="#{classroom_student_messages_path(classroom, student)}"]))
      expect(message_navigation["class"]).to include("border-blue-500")
      expect(response.body).to include("학생 메시지")
      expect(response.body).to include("보내기")
    end

    it "rejects a teacher outside the classroom from the student message page" do
      outsider = create(:user, :teacher)
      sign_in outsider

      get classroom_student_messages_path(classroom, student)

      expect(response).to redirect_to(root_path)
    end

    it "marks student-sent unread messages read when a teacher opens the message page" do
      classroom.update!(message_policy: "student_initiated")
      message = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "확인할 질문")
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      sign_in teacher

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(message.reload.read_at).to be_present
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
    end

    it "rejects teacher and admin root messages to an inactive student" do
      classroom.classroom_memberships.find_by!(user: student).inactive!

      [teacher, admin].each do |sender|
        sign_in sender

        expect {
          post classroom_student_messages_path(classroom, student),
               params: { user_message: { body: "비활성 학생 대상 메시지" } }
        }.not_to change(UserMessage, :count)

        expect(response).to have_http_status(:not_found)
        sign_out sender
      end
    end

    it "rejects a teacher root message when classroom messages are disabled" do
      classroom.update!(message_policy: "disabled")
      sign_in teacher

      expect {
        post classroom_student_messages_path(classroom, student),
             params: { user_message: { body: "비활성 교실 메시지" } }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(root_path)
    end

    it "shows a teacher root and student replies in the same thread card" do
      root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "선생님 메시지")
      create(:user_message, classroom: classroom, sender: student, recipient: teacher, parent_message: root, body: "학생 댓글")
      sign_in student

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("선생님 메시지")
      expect(response.body).to include("학생 댓글")
      expect(response.body).to include("reply_to_message_id")

      root_index = response.body.index("선생님 메시지")
      reply_index = response.body.index("학생 댓글")
      form_index = response.body.index("reply_to_message_id")

      expect(root_index).to be < reply_index
      expect(reply_index).to be < form_index
    end

    it "shows the newest root threads first and replies oldest first on the student page" do
      older_root = create(
        :user_message,
        classroom: classroom,
        sender: teacher,
        recipient: student,
        body: "오래된 원글",
        created_at: 2.days.ago
      )
      first_latest_root = create(
        :user_message,
        classroom: classroom,
        sender: teacher,
        recipient: student,
        body: "같은 시각의 첫 원글",
        created_at: 1.day.ago
      )
      second_latest_root = create(
        :user_message,
        classroom: classroom,
        sender: teacher,
        recipient: student,
        body: "같은 시각의 둘째 원글",
        created_at: first_latest_root.created_at
      )
      first_reply = create(
        :user_message,
        classroom: classroom,
        sender: student,
        recipient: teacher,
        parent_message: second_latest_root,
        body: "같은 시각의 첫 답글",
        created_at: 1.hour.ago
      )
      create(
        :user_message,
        classroom: classroom,
        sender: teacher,
        recipient: student,
        parent_message: second_latest_root,
        body: "같은 시각의 둘째 답글",
        created_at: first_reply.created_at
      )
      sign_in student

      get classroom_student_messages_path(classroom, student)

      second_root_index = response.body.index("같은 시각의 둘째 원글")
      first_root_index = response.body.index("같은 시각의 첫 원글")
      older_root_index = response.body.index(older_root.body)
      first_reply_index = response.body.index("같은 시각의 첫 답글")
      second_reply_index = response.body.index("같은 시각의 둘째 답글")

      expect(second_root_index).to be < first_root_index
      expect(first_root_index).to be < older_root_index
      expect(first_reply_index).to be < second_reply_index
    end

    it "shows the newest root threads first on the managed student page" do
      classroom.update!(message_policy: "student_initiated")
      first_root = create(
        :user_message,
        classroom: classroom,
        sender: student,
        recipient: teacher,
        body: "관리 화면 첫 원글",
        created_at: 1.day.ago
      )
      create(
        :user_message,
        classroom: classroom,
        sender: student,
        recipient: teacher,
        body: "관리 화면 둘째 원글",
        created_at: first_root.created_at
      )
      sign_in teacher

      get classroom_student_messages_path(classroom, student)

      expect(response.body.index("관리 화면 둘째 원글")).to be < response.body.index("관리 화면 첫 원글")
    end

    it "shows a student reply form under a student root thread when the classroom policy is replies only" do
      classroom.update!(message_policy: "student_initiated")
      student_root = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "먼저 질문")
      classroom.update!(message_policy: "replies_only")
      sign_in student

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("먼저 질문")
      expect(response.body).to include("reply_to_message_id")
      expect(response.body).to include(%(value="#{student_root.id}"))
      expect(response.body).not_to include('name="user_message[recipient_id]"')
    end

    it "does not show a student root message form when the classroom policy is replies only" do
      sign_in student

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="user_message[recipient_id]"')
    end

    it "rejects the student message page when classroom messages are disabled" do
      create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "숨겨질 메시지")
      classroom.update!(message_policy: "disabled")
      sign_in student

      get classroom_student_messages_path(classroom, student)

      expect(response).to redirect_to(root_path)
    end

    it "rejects the managed message page when classroom messages are disabled" do
      create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "숨겨질 메시지")
      classroom.update!(message_policy: "disabled")
      sign_in teacher

      get classroom_student_messages_path(classroom, student)

      expect(response).to redirect_to(root_path)
    end

    it "rejects the managed message page from an admin when classroom messages are disabled" do
      create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "숨겨질 메시지")
      classroom.update!(message_policy: "disabled")
      sign_in admin

      get classroom_student_messages_path(classroom, student)

      expect(response).to redirect_to(root_path)
    end

    it "shows a compact student root message form without choosing a teacher when the classroom policy is student initiated" do
      classroom.update!(message_policy: "student_initiated")
      outside_teacher = create(:user, :teacher, name: "다른 반 선생님")
      sign_in student

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="user_message[recipient_id]"')
      expect(response.body).not_to include("<select")
      expect(response.body).to include("보내기")
      expect(response.body).to include(student.name)
      expect(response.body).not_to include(outside_teacher.name)
    end

    it "rejects a student root message when the classroom policy is replies only" do
      sign_in student

      expect {
        post user_messages_path(student), params: {
          user_message: {
            recipient_id: teacher.id,
            body: "먼저 질문해도 될까요?"
          }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(user_path(student))
    end

    it "rejects a student root message when classroom messages are disabled" do
      classroom.update!(message_policy: "disabled")
      sign_in student

      expect {
        post user_messages_path(student), params: {
          user_message: { body: "먼저 질문해도 될까요?" }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(user_path(student))
    end

    it "creates one student root message when the classroom policy is student initiated" do
      classroom.update!(message_policy: "student_initiated")
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      sign_in student

      expect {
        post user_messages_path(student),
             params: {
               user_message: {
                 recipient_id: teacher.id,
                 body: "먼저 질문해도 될까요?"
               }
             },
             headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      message = UserMessage.find_by!(sender: student, parent_message_id: nil)
      expect([teacher, other_teacher]).to include(message.recipient)
      expect(message.body).to eq("먼저 질문해도 될까요?")
      expect(message.read_at).to be_nil
      expect(response.body.scan("먼저 질문해도 될까요?").size).to eq(1)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        classroom,
        :student_card_alerts,
        hash_including(
          target: dom_id(student, :student_card_alerts),
          partial: "users/student_card_alerts",
          locals: hash_including(user: student, unread_student_message: true)
        )
      )
    end

    it "rejects an inactive student root message" do
      classroom.update!(message_policy: "student_initiated")
      classroom.classroom_memberships.find_by!(user: student).inactive!
      sign_in student

      expect {
        post user_messages_path(student), params: {
          user_message: { body: "비활성 학생 질문" }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(user_path(student))
    end

    it "ignores arbitrary recipient_id and creates one message for a classroom teacher" do
      classroom.update!(message_policy: "student_initiated")
      outside_teacher = create(:user, :teacher)
      sign_in student

      expect {
        post user_messages_path(student), params: {
          user_message: {
            recipient_id: outside_teacher.id,
            body: "다른 반 선생님께 질문"
          }
        }
      }.to change(UserMessage, :count).by(1)

      message = UserMessage.find_by!(sender: student)
      expect([teacher, other_teacher]).to include(message.recipient)
      expect(message.recipient).not_to eq(outside_teacher)
    end

    it "does not create an automatic root message to an admin" do
      classroom.update!(message_policy: "student_initiated")
      sign_in student

      expect {
        post user_messages_path(student), params: {
          user_message: {
            recipient_id: admin.id,
            body: "관리자에게 질문"
          }
        }
      }.to change(UserMessage, :count).by(1)

      expect(UserMessage.find_by!(sender: student).recipient).not_to eq(admin)
    end

    it "allows a non-recipient classroom teacher to view the single student root thread" do
      classroom.update!(message_policy: "student_initiated")
      sign_in student

      post user_messages_path(student), params: {
        user_message: { body: "함께 확인할 질문" }
      }

      root_message = UserMessage.find_by!(sender: student, parent_message_id: nil)
      non_recipient_teacher = ([teacher, other_teacher] - [root_message.recipient]).first
      sign_out student
      sign_in non_recipient_teacher

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body.scan("함께 확인할 질문").size).to eq(1)
    end

    it "allows a non-recipient classroom teacher to reply to the single student root thread" do
      classroom.update!(message_policy: "student_initiated")
      sign_in student

      post user_messages_path(student), params: {
        user_message: { body: "공동 답변이 필요한 질문" }
      }

      root_message = UserMessage.find_by!(sender: student, parent_message_id: nil)
      non_recipient_teacher = ([teacher, other_teacher] - [root_message.recipient]).first
      sign_out student
      sign_in non_recipient_teacher

      expect {
        post classroom_student_messages_path(classroom, student),
          params: {
            reply_to_message_id: root_message.id,
            user_message: { body: "다른 선생님의 답변" }
          },
          headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      reply = UserMessage.order(:id).last
      expect(reply.sender).to eq(non_recipient_teacher)
      expect(reply.recipient).to eq(student)
      expect(reply.parent_message).to eq(root_message)
    end

    it "does not create a student root message when the enabled classroom has no teachers" do
      no_teacher_classroom = create(:classroom, message_policy: "student_initiated")
      create(:classroom_membership, user: student, classroom: no_teacher_classroom, role: "student")
      sign_in student

      expect {
        post user_messages_path(student), params: {
          user_message: { body: "선생님 계신가요?" }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(user_path(student))
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

    it "rejects an inactive student reply" do
      incoming = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "질문 있어?")
      classroom.classroom_memberships.find_by!(user: student).inactive!
      sign_in student

      expect {
        post user_messages_path(student), params: {
          reply_to_message_id: incoming.id,
          user_message: { body: "비활성 학생 답글" }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(user_path(student))
    end

    it "rejects a student reply when classroom messages are disabled" do
      incoming = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "질문 있어?")
      classroom.update!(message_policy: "disabled")
      sign_in student

      expect {
        post user_messages_path(student), params: {
          reply_to_message_id: incoming.id,
          user_message: { body: "네, 있어요." }
        }
      }.not_to change(UserMessage, :count)

      expect(response).to redirect_to(root_path)
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

    it "allows a student to reply under a student root thread after the classroom policy changes to replies only" do
      classroom.update!(message_policy: "student_initiated")
      student_root = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "먼저 질문")
      classroom.update!(message_policy: "replies_only")
      sign_in student

      expect {
        post user_messages_path(student),
             params: {
               reply_to_message_id: student_root.id,
               user_message: { body: "추가 질문" }
             },
             headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      expect(UserMessage.last.sender).to eq(student)
      expect(UserMessage.last.recipient).to eq(teacher)
      expect(UserMessage.last.parent_message).to eq(student_root)
    end

    it "shows a managed reply form under a student root message" do
      classroom.update!(message_policy: "student_initiated")
      student_root = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "먼저 질문")
      sign_in teacher

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("먼저 질문")
      expect(response.body).to include("reply_to_message_id")
      expect(response.body).to include(%(value="#{student_root.id}"))
    end

    it "shows a managed reply form under a teacher root message" do
      teacher_root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "선생님 원글")
      sign_in teacher

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("선생님 원글")
      expect(response.body).to include("reply_to_message_id")
      expect(response.body).to include(%(value="#{teacher_root.id}"))
    end

    it "continues to show existing message threads for an inactive student" do
      teacher_root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "기존 메시지")
      classroom.classroom_memberships.find_by!(user: student).inactive!
      sign_in teacher

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(teacher_root.body)
    end

    it "allows a teacher to reply under a student root message with turbo stream" do
      classroom.update!(message_policy: "student_initiated")
      student_root = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "먼저 질문")
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      sign_in teacher

      expect {
        post classroom_student_messages_path(classroom, student),
             params: {
               reply_to_message_id: student_root.id,
               user_message: { body: "선생님 답변" }
             },
             headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(UserMessage.last.sender).to eq(teacher)
      expect(UserMessage.last.recipient).to eq(student)
      expect(UserMessage.last.parent_message).to eq(student_root)
      expect(student_root.reload.read_at).to be_present
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        classroom,
        :student_card_alerts,
        hash_including(
          target: dom_id(student, :student_card_alerts),
          partial: "users/student_card_alerts",
          locals: hash_including(user: student, unread_student_message: false)
        )
      )
    end

    it "allows a teacher to reply under a teacher root message with turbo stream" do
      teacher_root = create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "선생님 원글")
      sign_in teacher

      expect {
        post classroom_student_messages_path(classroom, student),
             params: {
               reply_to_message_id: teacher_root.id,
               user_message: { body: "선생님 추가 답글" }
             },
             headers: turbo_headers
      }.to change(UserMessage, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(UserMessage.last.sender).to eq(teacher)
      expect(UserMessage.last.recipient).to eq(student)
      expect(UserMessage.last.parent_message).to eq(teacher_root)
    end

    it "allows an admin to reply under a student root message" do
      classroom.update!(message_policy: "student_initiated")
      student_root = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "먼저 질문")
      sign_in admin

      expect {
        post classroom_student_messages_path(classroom, student),
             params: {
               reply_to_message_id: student_root.id,
               user_message: { body: "관리자 답변" }
             }
      }.to change(UserMessage, :count).by(1)

      expect(UserMessage.last.sender).to eq(admin)
      expect(UserMessage.last.recipient).to eq(student)
      expect(UserMessage.last.parent_message).to eq(student_root)
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

    it "shows messages on the dedicated managed student message page" do
      sign_in teacher

      get classroom_student_messages_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("학생 메시지")
      expect(response.body).to include("보내기")
      expect(response.body).not_to include("최근 발급 쿠폰")
      expect(response.body).not_to include("칭찬 타임라인")
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
