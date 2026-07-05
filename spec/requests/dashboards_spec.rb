require "rails_helper"

RSpec.describe "Dashboards", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher) }
  let(:student) { create(:user, :student, student_pin: "1234") }

  describe "GET /dashboard" do
    it "redirects guests to sign in" do
      get dashboard_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the admin dashboard summary" do
      sign_in admin

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("한눈에 보기")
      expect(response.body).to include("전체 교실 수")
    end

    it "shows only assigned classrooms to teachers" do
      assigned_classroom = create(:classroom, name: "담당 교실")
      other_classroom = create(:classroom, name: "다른 교실")
      create(:classroom_membership, classroom: assigned_classroom, user: teacher, role: "teacher")
      sign_in teacher

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("한눈에 보기")
      expect(response.body).to include(assigned_classroom.name)
      expect(response.body).not_to include(other_classroom.name)
    end

    it "shows the student's weekday activity for the active session classroom" do
      classroom = create(:classroom, name: "학생 교실")
      other_classroom = create(:classroom)
      other_student = create(:user, :student)
      create(:classroom_membership, classroom: classroom, user: student, role: "student")
      create(:classroom_membership, classroom: other_classroom, user: student, role: "student")
      create(:classroom_membership, classroom: classroom, user: other_student, role: "student")

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        create(:compliment, classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 4, 6, 10, 0, 0))
        create(:compliment, classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 4, 6, 11, 0, 0))
        6.times do |index|
          create(:compliment,
            classroom: classroom,
            receiver: student,
            given_at: Time.zone.local(2026, 4, 6, 12 + index, 0, 0))
        end
        create(:compliment, classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 4, 8, 10, 0, 0))
        create(:compliment, classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 4, 11, 10, 0, 0))
        create(:compliment, classroom: other_classroom, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))
        create(:compliment, classroom: classroom, receiver: other_student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        create(:user_coupon,
          user: student,
          classroom: classroom,
          issuance_basis: "manual",
          issued_at: Time.zone.local(2026, 4, 6, 12, 0, 0))
        create(:user_coupon,
          user: student,
          classroom: classroom,
          status: :used,
          issuance_basis: "manual",
          issued_at: Time.zone.local(2026, 4, 7, 12, 0, 0),
          used_at: Time.zone.local(2026, 4, 8, 13, 0, 0))
        create(:user_coupon,
          user: student,
          classroom: classroom,
          issuance_basis: "manual",
          issued_at: Time.zone.local(2026, 3, 30, 12, 0, 0),
          period_start_on: Date.new(2026, 3, 30))
        create(:user_coupon,
          user: student,
          classroom: classroom,
          status: :used,
          issuance_basis: "manual",
          issued_at: Time.zone.local(2026, 3, 30, 12, 0, 0),
          used_at: Time.zone.local(2026, 4, 9, 13, 0, 0),
          period_start_on: Date.new(2026, 3, 30))
        create(:user_coupon,
          user: student,
          classroom: classroom,
          issuance_basis: "manual",
          issued_at: Time.zone.local(2026, 4, 11, 12, 0, 0))
        create(:user_coupon,
          user: student,
          classroom: other_classroom,
          issuance_basis: "manual",
          issued_at: Time.zone.local(2026, 4, 7, 12, 0, 0))
        create(:user_coupon,
          user: other_student,
          classroom: classroom,
          issuance_basis: "manual",
          issued_at: Time.zone.local(2026, 4, 7, 12, 0, 0))

        post classroom_student_login_path(classroom), params: {
          student_id: student.id,
          student_pin: "1234"
        }
        get dashboard_path
      end

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)

      expect(response.body).not_to include("#{classroom.name}에서 보낸 한 주를 살펴봐요.")
      expect(response.body).not_to include("오늘 받은 칭찬")
      expect(response.body).to include("지금까지 받은 칭찬")
      expect(response.body).to include("일주일 동안 받은 칭찬")
      expect(response.body).to include("일주일 동안 받은 쿠폰")
      expect(response.body).to include("일주일 동안 사용한 쿠폰")
      expect(document.at_css('[data-summary="total-praise"]')["data-count"]).to eq("10")
      expect(document.at_css('[data-summary="weekly-praise"]')["data-count"]).to eq("9")
      expect(document.at_css('[data-summary="held-coupons"]')["data-count"]).to eq("3")
      expect(document.at_css('[data-summary="weekly-issued-coupons"]')["data-count"]).to eq("2")
      expect(document.at_css('[data-summary="weekly-used-coupons"]')["data-count"]).to eq("2")
      graph = document.at_css('svg[aria-label="월요일부터 금요일까지 받은 칭찬과 쿠폰 활동 그래프"]')
      expect(graph).to be_present
      expect(graph.at_css('[data-graph-series="praise"]')["stroke"]).to eq("#3b82f6")
      expect(graph.css('[data-graph-point="praise"]').count).to eq(5)
      expect(graph.css("[data-y-axis-tick]").map { |tick| tick["data-y-axis-tick"] }).to contain_exactly("0", "2", "4", "6", "8")

      expected_activity = {
        "월" => %w[8 1 0],
        "화" => %w[0 1 0],
        "수" => %w[1 0 1],
        "목" => %w[0 0 1],
        "금" => %w[0 0 0]
      }
      expected_activity.each do |weekday, counts|
        graph_activity = document.at_css(%([data-graph-weekday="#{weekday}"]))

        expect([
          graph_activity["data-praise-count"],
          graph_activity["data-issued-coupon-count"],
          graph_activity["data-used-coupon-count"]
        ]).to eq(counts)
      end
      expect(response.body).to include("2026.04.06 ~ 2026.04.10")
      expect(document.at_css('a[aria-label="이전 주 보기"]')["href"]).to eq(dashboard_path(week_offset: -1))
      expect(document.at_css('a[aria-label="다음 주 보기"]')["href"]).to eq(dashboard_path(week_offset: 1))
      expect(response.body).not_to include("선택한 주의 활동은 아직 없어요.")

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        get dashboard_path, params: { week_offset: -1 }
      end

      previous_week_document = Nokogiri::HTML(response.body)
      expect(response.body).to include("2026.03.30 ~ 2026.04.03")
      expect(previous_week_document.at_css('[data-summary="total-praise"]')["data-count"]).to eq("10")
      expect(previous_week_document.at_css('[data-summary="weekly-praise"]')["data-count"]).to eq("0")
      expect(previous_week_document.at_css('[data-summary="weekly-issued-coupons"]')["data-count"]).to eq("2")
      expect(previous_week_document.at_css('[data-summary="held-coupons"]')["data-count"]).to eq("3")
    end

    it "shows an empty state when the student has no weekday activity" do
      classroom = create(:classroom, name: "학생 교실")
      create(:classroom_membership, classroom: classroom, user: student, role: "student")

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        post classroom_student_login_path(classroom), params: {
          student_id: student.id,
          student_pin: "1234"
        }
        get dashboard_path
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("선택한 주의 활동은 아직 없어요.")
      expect(response.body).not_to include("새로운 칭찬과 쿠폰 기록을 기다려 볼까요?")
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('[data-summary="weekly-praise"]')["data-count"]).to eq("0")
      expect(document.at_css('[data-summary="weekly-issued-coupons"]')["data-count"]).to eq("0")
      expect(document.at_css('[data-summary="weekly-used-coupons"]')["data-count"]).to eq("0")
      expect(document.css("[data-graph-weekday]").count).to eq(5)
      expect(document.css("[data-graph-date]").map { |date| date["data-graph-date"] }).to contain_exactly("4/6", "4/7", "4/8", "4/9", "4/10")
      expect(document.css("[data-grid-line]").count).to eq(5)
      expect(document.css("[data-y-axis-tick]")).to be_empty
      expect(document.at_css('[data-graph-series="praise"]')).to be_nil
      expect(document.css('[data-graph-point="praise"]')).to be_empty
    end

    it "redirects students without an active session classroom membership to student login" do
      sign_in student

      get dashboard_path

      expect(response).to redirect_to(new_student_session_path)
    end
  end
end
