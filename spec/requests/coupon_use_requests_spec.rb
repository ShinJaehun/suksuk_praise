require "rails_helper"

RSpec.describe "Coupon use requests", type: :request do
  include ActionView::RecordIdentifier

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
      issued_at: 2.days.from_now,
      period_start_on: 2.days.from_now.to_date,
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

  it "broadcasts a student card badge update after a student requests coupon use" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    sign_in student

    post request_user_coupon_use_path(student, coupon)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
      classroom,
      :student_card_alerts,
      hash_including(
        target: dom_id(student, :student_card_alerts),
        partial: "users/student_card_alerts",
        locals: hash_including(user: student, pending_coupon_request: true)
      )
    )
  end

  it "broadcasts student coupon list updates after a student requests coupon use" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    sign_in student

    post request_user_coupon_use_path(student, coupon)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      student,
      :student_coupons,
      hash_including(
        target: dom_id(student, :coupons),
        partial: "user_coupons/list",
        locals: hash_including(
          coupons: a_kind_of(ActiveRecord::Relation),
          user: student,
          viewer: student,
          pending_coupon_use_requests_by_coupon_id: hash_including(coupon.id => a_kind_of(CouponUseRequest))
        )
      )
    )
    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      student,
      :managed_coupons,
      hash_including(
        target: dom_id(student, :coupons),
        partial: "user_coupons/list",
        locals: hash_including(
          coupons: a_kind_of(ActiveRecord::Relation),
          user: student,
          viewer: nil,
          pending_coupon_use_requests_by_coupon_id: hash_including(coupon.id => a_kind_of(CouponUseRequest))
        )
      )
    )
  end

  it "rejects a student requesting another student's coupon" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    other_student = create(:user, :student)
    sign_in other_student

    expect {
      post request_user_coupon_use_path(student, coupon)
    }.not_to change(CouponUseRequest, :count)

    expect(response).to redirect_to(root_path)
    expect(coupon.reload).to be_issued
    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_replace_to)
    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
  end

  it "does not create duplicate pending requests" do
    create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    sign_in student

    expect {
      post request_user_coupon_use_path(student, coupon)
    }.not_to change(CouponUseRequest.pending, :count)

    expect(response).to have_http_status(:see_other)
    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_replace_to)
    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
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

  it "broadcasts a student card badge removal after the last pending request is approved" do
    request = create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    sign_in teacher

    patch approve_coupon_use_request_path(request)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
      classroom,
      :student_card_alerts,
      hash_including(
        target: dom_id(student, :student_card_alerts),
        partial: "users/student_card_alerts",
        locals: hash_including(user: student, pending_coupon_request: false)
      )
    )
  end

  it "broadcasts student coupon list updates after a request is approved" do
    request = create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    sign_in teacher

    patch approve_coupon_use_request_path(request)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      student,
      :student_coupons,
      hash_including(
        target: dom_id(student, :coupons),
        partial: "user_coupons/list",
        locals: hash_including(
          coupons: a_kind_of(ActiveRecord::Relation),
          user: student,
          viewer: student,
          pending_coupon_use_requests_by_coupon_id: {}
        )
      )
    )
    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      student,
      :managed_coupons,
      hash_including(
        target: dom_id(student, :coupons),
        partial: "user_coupons/list",
        locals: hash_including(
          coupons: a_kind_of(ActiveRecord::Relation),
          user: student,
          viewer: nil,
          pending_coupon_use_requests_by_coupon_id: {}
        )
      )
    )
  end

  it "keeps the student card badge when another pending request remains after approval" do
    request = create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)
    other_coupon = create(
      :user_coupon,
      user: student,
      classroom: classroom,
      coupon_template: template,
      issued_by: teacher,
      issued_at: 1.day.from_now,
      period_start_on: 1.day.from_now.to_date,
      status: :issued
    )
    create(:coupon_use_request, user_coupon: other_coupon, classroom: classroom, student: student, requested_by: student)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    sign_in teacher

    patch approve_coupon_use_request_path(request)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
      classroom,
      :student_card_alerts,
      hash_including(
        target: dom_id(student, :student_card_alerts),
        partial: "users/student_card_alerts",
        locals: hash_including(user: student, pending_coupon_request: true)
      )
    )
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
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    sign_in outsider_teacher

    expect {
      patch approve_coupon_use_request_path(request)
    }.not_to change(CouponEvent, :count)

    expect(response).to redirect_to(root_path)
    expect(coupon.reload).to be_issued
    expect(request.reload).to be_pending
    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_replace_to)
    expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
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
