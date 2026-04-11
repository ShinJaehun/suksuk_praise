require "rails_helper"

RSpec.describe "Classrooms#draw_coupon", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "POST /classrooms/:id/draw_coupon" do
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let!(:membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }
    let!(:template) { create(:coupon_template, created_by: teacher, active: true, weight: 100) }

    def json_body
      JSON.parse(response.body)
    end

    it "rejects a guest user before authorization" do
      expect {
        post draw_coupon_classroom_path(classroom),
          params: { basis: "manual", mode: "default", user_id: student.id },
          as: :json
      }.not_to change(UserCoupon, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it "allows an admin to draw a coupon" do
      admin = create(:user, :admin)
      admin_template = create(:coupon_template, created_by: admin, active: true, weight: 100)
      sign_in admin

      expect {
        post draw_coupon_classroom_path(classroom),
          params: { basis: "manual", mode: "default", user_id: student.id },
          as: :json
      }.to change(UserCoupon, :count).by(1)
        .and change(CouponEvent, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body["user_id"]).to eq(student.id)
      expect(UserCoupon.last.coupon_template).to eq(admin_template)
      expect(CouponEvent.last).to have_attributes(action: "issued", actor: admin)
    end

    it "allows the classroom teacher to draw a coupon" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      sign_in teacher

      post draw_coupon_classroom_path(classroom),
        params: { basis: "manual", mode: "default", user_id: student.id },
        as: :json

      expect(response).to have_http_status(:created)
      expect(UserCoupon.last.issued_by).to eq(teacher)
      expect(UserCoupon.last.coupon_template).to eq(template)
    end

    it "rejects a student" do
      sign_in student

      expect {
        post draw_coupon_classroom_path(classroom),
          params: { basis: "manual", mode: "default", user_id: student.id },
          as: :json
      }.not_to change(UserCoupon, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq("ok" => false, "error" => "not_authorized")
    end

    it "rejects a teacher who is not a teacher member of the classroom" do
      outsider = create(:user, :teacher)
      create(:coupon_template, created_by: outsider, active: true, weight: 100)
      sign_in outsider

      expect {
        post draw_coupon_classroom_path(classroom),
          params: { basis: "manual", mode: "default", user_id: student.id },
          as: :json
      }.not_to change(UserCoupon, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq("ok" => false, "error" => "not_authorized")
    end

    it "creates a coupon and issued event on success" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      sign_in teacher

      expect {
        post draw_coupon_classroom_path(classroom),
          params: { basis: "manual", mode: "default", user_id: student.id },
          as: :json
      }.to change(UserCoupon, :count).by(1)
        .and change(CouponEvent, :count).by(1)

      coupon = UserCoupon.order(:id).last
      event = CouponEvent.order(:id).last

      expect(coupon.user).to eq(student)
      expect(coupon.classroom).to eq(classroom)
      expect(coupon.coupon_template).to eq(template)
      expect(event).to have_attributes(action: "issued", user_coupon: coupon, actor: teacher)
    end

    it "returns 409 when the same daily/default draw is requested twice" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        post draw_coupon_classroom_path(classroom),
          params: { basis: "daily", mode: "default", user_id: student.id },
          as: :json

        expect(response).to have_http_status(:created)

        expect {
          post draw_coupon_classroom_path(classroom),
            params: { basis: "daily", mode: "default", user_id: student.id },
            as: :json
        }.not_to change(UserCoupon, :count)

        expect(response).to have_http_status(:conflict)
      end
    end
  end
end
