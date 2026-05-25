require "rails_helper"

RSpec.describe "Classroom pending coupon use request badge", type: :request do
  include ActionView::RecordIdentifier

  let(:classroom) { create(:classroom) }
  let(:student) { create(:user, :student) }
  let(:teacher) { create(:user, :teacher) }
  let(:template) { create(:coupon_template, created_by: teacher) }
  let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }
  let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
  let!(:coupon) do
    create(:user_coupon, user: student, classroom: classroom, coupon_template: template, issued_by: teacher)
  end

  it "shows a coupon request badge on the student card for a classroom teacher" do
    create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in teacher

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("쿠폰 요청")
    expect(response.body).to include(classroom_student_path(classroom, student, anchor: dom_id(student, :coupons)))
  end

  it "does not show the badge when there is no pending request" do
    sign_in teacher

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("쿠폰 요청")
  end

  it "shows a coupon request badge to an admin" do
    admin = create(:user, :admin)
    create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in admin

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("쿠폰 요청")
  end

  it "does not expose the badge to a student" do
    create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in student

    get classroom_path(classroom)

    expect(response).to redirect_to(user_path(student))
    expect(response.body).not_to include("쿠폰 요청")
  end

  it "does not expose the badge to a teacher outside the classroom" do
    outsider = create(:user, :teacher)
    create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in outsider

    get classroom_path(classroom)

    expect(response).to redirect_to(root_path)
    expect(response.body).not_to include("쿠폰 요청")
  end
end
