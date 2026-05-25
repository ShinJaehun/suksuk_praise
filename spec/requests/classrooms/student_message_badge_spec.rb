require "rails_helper"

RSpec.describe "Classroom student message badge", type: :request do
  include ActionView::RecordIdentifier

  let(:classroom) { create(:classroom) }
  let(:student) { create(:user, :student) }
  let(:teacher) { create(:user, :teacher) }
  let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }
  let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }

  it "shows a message badge for unread student-sent messages" do
    classroom.update!(student_initiated_messages_enabled: true)
    create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "질문")
    sign_in teacher

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("새 메시지")
    expect(response.body).to include(classroom_student_path(classroom, student, anchor: dom_id(student, :message_section)))
  end

  it "does not show a message badge for teacher-sent messages" do
    create(:user_message, classroom: classroom, sender: teacher, recipient: student, body: "안내")
    sign_in teacher

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("새 메시지")
  end

  it "marks unread student messages read when a teacher opens the managed student page" do
    classroom.update!(student_initiated_messages_enabled: true)
    message = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "질문")
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    sign_in teacher

    get classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(message.reload.read_at).to be_present
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

  it "does not mark unread student messages read when the student opens their own page" do
    classroom.update!(student_initiated_messages_enabled: true)
    message = create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "질문")
    sign_in student

    get classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(message.reload.read_at).to be_nil
  end
end
