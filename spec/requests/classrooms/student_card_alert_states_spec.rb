require "rails_helper"

RSpec.describe "Classroom student card alert state", type: :request do
  let(:classroom) { create(:classroom, message_policy: "student_initiated") }
  let(:teacher) { create(:user, :teacher) }
  let(:student) { create(:user, :student) }
  let(:inactive_student) { create(:user, :student) }
  let(:other_student) { create(:user, :student) }
  let(:template) { create(:coupon_template, created_by: teacher) }

  before do
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    create(:classroom_membership, classroom: classroom, user: student, role: "student")
  end

  it "returns alert student IDs for active students in the classroom" do
    inactive_membership = create(
      :classroom_membership,
      classroom: classroom,
      user: inactive_student,
      role: "student"
    )
    other_classroom = create(:classroom, message_policy: "student_initiated")
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: "student")

    coupon = create(:user_coupon, user: student, classroom: classroom, coupon_template: template, issued_by: teacher)
    inactive_coupon = create(:user_coupon, user: inactive_student, classroom: classroom, coupon_template: template, issued_by: teacher)
    other_coupon = create(:user_coupon, user: other_student, classroom: other_classroom, coupon_template: template, issued_by: teacher)
    create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    create(:coupon_use_request, user_coupon: inactive_coupon, classroom: classroom, student: inactive_student, requested_by: inactive_student)
    create(:coupon_use_request, user_coupon: other_coupon, classroom: other_classroom, student: other_student, requested_by: other_student)
    create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "질문")
    create(:user_message, classroom: classroom, sender: inactive_student, recipient: teacher, body: "지난 질문")
    inactive_membership.update!(status: "inactive")
    sign_in teacher

    get classroom_student_card_alert_state_path(classroom), as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "pending_coupon_request_student_ids" => [student.id],
      "unread_student_message_student_ids" => [student.id]
    )
  end

  it "returns no unread message IDs when student messages are disabled" do
    create(:user_message, classroom: classroom, sender: student, recipient: teacher, body: "질문")
    classroom.update!(message_policy: "disabled")
    sign_in teacher

    get classroom_student_card_alert_state_path(classroom), as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["unread_student_message_student_ids"]).to eq([])
  end

  it "rejects a student" do
    sign_in student

    get classroom_student_card_alert_state_path(classroom), as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a teacher outside the classroom" do
    sign_in create(:user, :teacher)

    get classroom_student_card_alert_state_path(classroom), as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
