require "rails_helper"

RSpec.describe "UserCoupons#create", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:user, :student) }
  let(:teacher) { create(:user, :teacher) }
  let!(:student_membership) do
    create(:classroom_membership, classroom: classroom, user: student, role: "student")
  end
  let!(:teacher_membership) do
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
  end
  let!(:template) do
    create(:coupon_template, created_by: teacher, active: true, title: "선택 쿠폰")
  end

  it "allows a classroom teacher to assign a selected active template" do
    sign_in teacher

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: template.id },
        as: :json
    }.to change(UserCoupon, :count).by(1)
      .and change(CouponEvent, :count).by(1)

    expect(response).to have_http_status(:created)
    coupon = UserCoupon.order(:id).last
    event = CouponEvent.order(:id).last
    expect(coupon).to have_attributes(
      user: student,
      classroom: classroom,
      coupon_template: template,
      issued_by: teacher,
      status: "issued",
      issuance_basis: "manual",
      basis_tag: "selected"
    )
    expect(event).to have_attributes(
      action: "issued",
      actor: teacher,
      user_coupon: coupon,
      classroom: classroom,
      coupon_template: template
    )
    expect(event.metadata).to include(
      "basis" => "manual",
      "mode" => "selected",
      "target_user_id" => student.id
    )
  end

  it "allows an admin to assign one of their active personal templates" do
    admin = create(:user, :admin)
    admin_template = create(:coupon_template, created_by: admin, active: true)
    sign_in admin

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: admin_template.id },
        as: :json
    }.to change(UserCoupon, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(UserCoupon.last.coupon_template).to eq(admin_template)
  end

  it "rejects an unassigned school manager" do
    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: classroom.school, user: manager)
    manager_template = create(:coupon_template, created_by: manager, active: true)
    sign_in manager

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: manager_template.id },
        as: :json
    }.not_to change(UserCoupon, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a teacher outside the classroom" do
    outsider = create(:user, :teacher)
    outsider_template = create(:coupon_template, created_by: outsider, active: true)
    sign_in outsider

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: outsider_template.id },
        as: :json
    }.not_to change(UserCoupon, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a student" do
    sign_in student

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: template.id },
        as: :json
    }.not_to change(UserCoupon, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects an inactive student target" do
    student_membership.inactive!
    sign_in teacher

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: template.id },
        as: :json
    }.not_to change(UserCoupon, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "rejects a nonexistent template" do
    sign_in teacher

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: -1 },
        as: :json
    }.not_to change(UserCoupon, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "rejects a template outside the current policy scope" do
    other_teacher = create(:user, :teacher)
    inaccessible_template = create(:coupon_template, created_by: other_teacher, active: true)
    sign_in teacher

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: inaccessible_template.id },
        as: :json
    }.not_to change(UserCoupon, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "rejects an inactive template" do
    template.update!(active: false)
    sign_in teacher

    expect {
      post classroom_student_coupons_path(classroom, student),
        params: { coupon_template_id: template.id },
        as: :json
    }.not_to change(UserCoupon, :count)

    expect(response).to have_http_status(:not_found)
  end
end
