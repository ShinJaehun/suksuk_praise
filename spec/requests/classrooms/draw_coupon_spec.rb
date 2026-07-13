require "rails_helper"

RSpec.describe "Classrooms#draw_coupon", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include ActionView::RecordIdentifier

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

    it "returns a turbo stream with the draw animation and deferred coupon area updates" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      sign_in teacher

      post draw_coupon_classroom_path(classroom),
        params: { basis: "manual", mode: "default", user_id: student.id },
        headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      fragment = Nokogiri::HTML.fragment(response.body)
      top_level_update_targets = fragment.children
        .select { |node| node.element? && node.name == "turbo-stream" && node["action"] == "update" }
        .map { |node| node["target"] }

      expect(response.body).to include("coupon-animation")
      expect(response.body).to include("data-coupon-animation-target=\"deferredStream\"")
      expect(response.body).to include("data-coupon-animation-reveal-url-value=")
      expect(response.body).to include(reveal_issued_user_coupon_path(UserCoupon.order(:id).last))
      expect(response.body).to include(dom_id(student, :coupons))
      expect(response.body).to include(dom_id(student, :recent_issued_coupons))
      expect(top_level_update_targets).not_to include(dom_id(student, :coupons))
      expect(top_level_update_targets).not_to include(dom_id(student, :recent_issued_coupons))
    end

    it "does not immediately broadcast the issued coupon list to the student's coupon stream" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
      sign_in teacher

      post draw_coupon_classroom_path(classroom),
        params: { basis: "manual", mode: "default", user_id: student.id },
        headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
    end

    it "does not immediately broadcast the issued weekly king coupon list to the winning student's coupon stream" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      classroom.update!(weekly_compliment_king_enabled: true)
      allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post draw_coupon_classroom_path(classroom),
          params: { basis: "weekly", mode: "weekly_top", user_id: student.id },
          headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }
      end

      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
    end

    it "returns a visible compliment king frame after drawing a weekly king coupon" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      classroom.update!(weekly_compliment_king_enabled: true)
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post draw_coupon_classroom_path(classroom),
          params: { basis: "weekly", mode: "weekly_top", user_id: student.id },
          headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }
      end

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      fragment = Nokogiri::HTML.fragment(response.body)
      frame = fragment.at_css(%(turbo-frame##{dom_id(classroom, :compliment_king_weekly)}))
      expect(frame).to be_present
      expect(frame.key?("hidden")).to eq(false)
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

    it "rejects an unassigned school manager" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: classroom.school, user: manager)
      sign_in manager

      expect {
        post draw_coupon_classroom_path(classroom),
          params: { basis: "manual", mode: "default", user_id: student.id },
          as: :json
      }.not_to change(UserCoupon, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq("ok" => false, "error" => "not_authorized")
    end

    it "rejects an inactive student target" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      membership.inactive!
      sign_in teacher

      expect {
        post draw_coupon_classroom_path(classroom),
          params: { basis: "manual", mode: "default", user_id: student.id },
          as: :json
      }.not_to change(UserCoupon, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq("ok" => false, "error" => "user_not_in_classroom")
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

    it "rejects a direct weekly king draw when weekly compliment king is disabled" do
      other_student = create(:user, :student)
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      create(:classroom_membership, user: other_student, classroom: classroom, role: "student")
      existing_coupon = create(
        :user_coupon,
        user: other_student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher,
        issuance_basis: "manual",
        basis_tag: "default"
      )
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        expect do
          post draw_coupon_classroom_path(classroom),
            params: { basis: "weekly", mode: "weekly_top", user_id: student.id },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }
        end.not_to change { [UserCoupon.count, CouponEvent.count] }
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("이 교실에서는 해당 칭찬왕 기능을 사용하지 않습니다.")
      expect(existing_coupon.reload).to be_issued
      expect(classroom.reload.weekly_compliment_king_enabled?).to eq(false)
    end

    it "rejects a direct monthly king draw when monthly compliment king is disabled" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      sign_in teacher

      expect do
        post draw_coupon_classroom_path(classroom),
          params: { basis: "monthly", mode: "monthly_top", user_id: student.id },
          as: :json
      end.not_to change { [UserCoupon.count, CouponEvent.count] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq(
        "ok" => false,
        "error" => "invalid",
        "detail" => "coupons.draw.compliment_king_disabled"
      )
    end

    it "rejects a direct daily king draw when daily compliment king is disabled" do
      classroom.update!(daily_compliment_king_enabled: false)
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      sign_in teacher

      expect do
        post draw_coupon_classroom_path(classroom),
          params: { basis: "daily", mode: "daily_top", user_id: student.id },
          as: :json
      end.not_to change { [UserCoupon.count, CouponEvent.count] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["detail"]).to eq("coupons.draw.compliment_king_disabled")
    end

    it "creates a weekly coupon for the weekly compliment king" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      classroom.update!(weekly_compliment_king_enabled: true)
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 8, 9, 0, 0))

        post draw_coupon_classroom_path(classroom),
          params: { basis: "weekly", mode: "weekly_top", user_id: student.id },
          as: :json

        expect(response).to have_http_status(:created)
        expect(UserCoupon.last.issuance_basis).to eq("weekly")
      end
    end

    it "creates a monthly coupon for the monthly compliment king" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      classroom.update!(monthly_compliment_king_enabled: true)
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 20, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 2, 10, 0, 0))
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 20, 9, 0, 0))

        post draw_coupon_classroom_path(classroom),
          params: { basis: "monthly", mode: "monthly_top", user_id: student.id },
          as: :json

        expect(response).to have_http_status(:created)
        expect(UserCoupon.last.issuance_basis).to eq("monthly")
      end
    end

    it "returns 409 when the same weekly draw is requested twice in one week" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      classroom.update!(weekly_compliment_king_enabled: true)
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post draw_coupon_classroom_path(classroom),
          params: { basis: "weekly", mode: "weekly_top", user_id: student.id },
          as: :json

        expect(response).to have_http_status(:created)

        expect {
          post draw_coupon_classroom_path(classroom),
            params: { basis: "weekly", mode: "weekly_top", user_id: student.id },
            as: :json
        }.not_to change(UserCoupon, :count)

        expect(response).to have_http_status(:conflict)
      end
    end

    it "returns 409 when a used weekly top coupon already exists for the same week" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      classroom.update!(weekly_compliment_king_enabled: true)
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))
        create(
          :user_coupon,
          user: student,
          classroom: classroom,
          coupon_template: template,
          issued_by: teacher,
          issuance_basis: "weekly",
          basis_tag: "weekly_top",
          period_start_on: Date.new(2026, 4, 6),
          status: :used
        )

        expect {
          post draw_coupon_classroom_path(classroom),
            params: { basis: "weekly", mode: "weekly_top", user_id: student.id },
            as: :json
        }.not_to change(UserCoupon, :count)

        expect(response).to have_http_status(:conflict)
      end
    end

    it "returns 409 when the same monthly draw is requested twice in one month" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      classroom.update!(monthly_compliment_king_enabled: true)
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 20, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 2, 10, 0, 0))

        post draw_coupon_classroom_path(classroom),
          params: { basis: "monthly", mode: "monthly_top", user_id: student.id },
          as: :json

        expect(response).to have_http_status(:created)

        expect {
          post draw_coupon_classroom_path(classroom),
            params: { basis: "monthly", mode: "monthly_top", user_id: student.id },
            as: :json
        }.not_to change(UserCoupon, :count)

        expect(response).to have_http_status(:conflict)
      end
    end

    it "returns 409 when a used monthly top coupon already exists for the same month" do
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
      classroom.update!(monthly_compliment_king_enabled: true)
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 20, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 2, 10, 0, 0))
        create(
          :user_coupon,
          user: student,
          classroom: classroom,
          coupon_template: template,
          issued_by: teacher,
          issuance_basis: "monthly",
          basis_tag: "monthly_top",
          period_start_on: Date.new(2026, 4, 1),
          status: :used
        )

        expect {
          post draw_coupon_classroom_path(classroom),
            params: { basis: "monthly", mode: "monthly_top", user_id: student.id },
            as: :json
        }.not_to change(UserCoupon, :count)

        expect(response).to have_http_status(:conflict)
      end
    end
  end
end
