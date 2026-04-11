require "rails_helper"

RSpec.describe "UserCoupons#use", type: :request do
  describe "POST /users/:user_id/coupons/:id/use" do
    let(:student) { create(:user, :student) }
    let(:teacher) { create(:user, :teacher) }
    let(:classroom) { create(:classroom) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }
    let!(:template) { create(:coupon_template, created_by: teacher, active: true, weight: 100) }
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

    def json_body
      JSON.parse(response.body)
    end

    it "rejects a guest user before authorization" do
      expect {
        post use_user_coupon_path(student, coupon), as: :json
      }.not_to change(CouponEvent, :count)

      expect(response).to have_http_status(:unauthorized)
      expect(coupon.reload).to be_issued
    end

    it "allows an admin to use a coupon" do
      admin = create(:user, :admin)
      sign_in admin

      expect {
        post use_user_coupon_path(student, coupon), as: :json
      }.to change(CouponEvent, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(coupon.reload).to be_used
      expect(CouponEvent.last).to have_attributes(action: "used", actor: admin, user_coupon: coupon)
    end

    it "allows the classroom teacher to use a student's coupon" do
      sign_in teacher

      post use_user_coupon_path(student, coupon), as: :json

      expect(response).to have_http_status(:ok)
      expect(coupon.reload).to be_used
    end

    it "allows the owner student to use their coupon" do
      sign_in student

      post use_user_coupon_path(student, coupon), as: :json

      expect(response).to have_http_status(:ok)
      expect(coupon.reload).to be_used
    end

    it "rejects another student" do
      other_student = create(:user, :student)
      sign_in other_student

      expect {
        post use_user_coupon_path(student, coupon), as: :json
      }.not_to change(CouponEvent, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq("ok" => false, "error" => "not_authorized")
      expect(coupon.reload).to be_issued
    end

    it "returns 409 for an already used coupon" do
      sign_in teacher
      coupon.update!(status: :used, used_at: Time.zone.local(2026, 4, 7, 11, 0, 0))

      expect {
        post use_user_coupon_path(student, coupon), as: :json
      }.not_to change(CouponEvent, :count)

      expect(response).to have_http_status(:conflict)
      expect(json_body["ok"]).to eq(false)
    end

    it "creates a used event on success" do
      sign_in teacher

      expect {
        post use_user_coupon_path(student, coupon), as: :json
      }.to change(CouponEvent, :count).by(1)

      event = CouponEvent.order(:id).last

      expect(event).to have_attributes(action: "used", actor: teacher, user_coupon: coupon)
      expect(event.metadata["target_user_id"]).to eq(student.id)
    end
  end
end
