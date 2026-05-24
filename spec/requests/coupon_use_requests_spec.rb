require "rails_helper"

RSpec.describe "Coupon use requests", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:user, :student) }
  let(:teacher) { create(:user, :teacher) }
  let(:outsider_teacher) { create(:user, :teacher) }
  let(:template) { create(:coupon_template, created_by: teacher) }
  let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }
  let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
  let!(:coupon) do
    create(
      :user_coupon,
      user: student,
      classroom: classroom,
      coupon_template: template,
      issued_by: teacher,
      status: :issued
    )
  end

  it "allows a student to request use of their own coupon" do
    sign_in student

    expect {
      post request_user_coupon_use_path(student, coupon)
    }.to change(CouponUseRequest.pending, :count).by(1)

    expect(response).to have_http_status(:see_other)
    expect(coupon.reload).to be_issued
  end

  it "rejects a student requesting another student's coupon" do
    other_student = create(:user, :student)
    sign_in other_student

    expect {
      post request_user_coupon_use_path(student, coupon)
    }.not_to change(CouponUseRequest, :count)

    expect(response).to redirect_to(root_path)
    expect(coupon.reload).to be_issued
  end

  it "does not create duplicate pending requests" do
    create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in student

    expect {
      post request_user_coupon_use_path(student, coupon)
    }.not_to change(CouponUseRequest.pending, :count)

    expect(response).to have_http_status(:see_other)
  end

  it "allows a classroom teacher to approve a request" do
    request = create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in teacher

    expect {
      patch approve_coupon_use_request_path(request)
    }.to change(CouponEvent, :count).by(1)

    expect(response).to have_http_status(:see_other)
    expect(coupon.reload).to be_used
    expect(request.reload).to be_approved
    expect(request.resolved_by).to eq(teacher)
  end

  it "allows an admin to approve a request" do
    admin = create(:user, :admin)
    request = create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in admin

    patch approve_coupon_use_request_path(request)

    expect(coupon.reload).to be_used
    expect(request.reload).to be_approved
  end

  it "rejects approval by a teacher outside the classroom" do
    request = create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in outsider_teacher

    expect {
      patch approve_coupon_use_request_path(request)
    }.not_to change(CouponEvent, :count)

    expect(response).to redirect_to(root_path)
    expect(coupon.reload).to be_issued
    expect(request.reload).to be_pending
  end

  it "does not use a coupon twice when approving an already approved request" do
    request = create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    sign_in teacher

    patch approve_coupon_use_request_path(request)
    expect {
      patch approve_coupon_use_request_path(request)
    }.not_to change(CouponEvent, :count)

    expect(coupon.reload).to be_used
    expect(request.reload).to be_approved
  end
end
