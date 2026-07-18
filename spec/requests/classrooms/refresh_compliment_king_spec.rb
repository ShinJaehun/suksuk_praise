require "rails_helper"

RSpec.describe "Classrooms#refresh_compliment_king", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include ActionView::RecordIdentifier

  describe "POST /classrooms/:id/refresh_compliment_king" do
    let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }

    before do
      sign_in teacher
    end

    it "renders the daily king card for daily period" do
      travel_to Time.zone.local(2026, 4, 7, 12, 0, 0) do
        create(:school_closure, school: classroom.school, starts_on: Date.new(2026, 4, 7), ends_on: Date.new(2026, 4, 7))
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post refresh_compliment_king_classroom_path(classroom), params: { period: "daily" }, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("오늘의 칭찬왕")
        expect(response.body).to include(student.name)
        expect(response.body).to include("쿠폰 뽑기")
        expect(response.body).not_to include("랜덤 쿠폰 뽑기")
        fragment = Nokogiri::HTML.fragment(response.body)
        frame = fragment.at_css(%(turbo-frame##{dom_id(classroom, :compliment_king_daily)}))
        expect(frame).to be_present
        expect(frame.key?("hidden")).to eq(false)
      end
    end

    it "renders the weekly king card for weekly period when enabled" do
      classroom.update!(weekly_compliment_king_enabled: true)
      travel_to Time.zone.local(2026, 4, 10, 12, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post refresh_compliment_king_classroom_path(classroom), params: { period: "weekly" }, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("이번 주 칭찬왕")
        expect(response.body).to include(student.name)
      end
    end

    it "renders the monthly king card for monthly period when enabled" do
      classroom.update!(monthly_compliment_king_enabled: true)
      travel_to Time.zone.local(2026, 4, 30, 12, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

        post refresh_compliment_king_classroom_path(classroom), params: { period: "monthly" }, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("이번 달 칭찬왕")
        expect(response.body).to include(student.name)
      end
    end

    it "redirects a weekly refresh before the last school day without picking a king" do
      classroom.update!(weekly_compliment_king_enabled: true)

      travel_to Time.zone.local(2026, 4, 8, 12, 0, 0) do
        expect(ComplimentKings::Pick).not_to receive(:call)

        post refresh_compliment_king_classroom_path(classroom), params: { period: "weekly" }, headers: turbo_headers
      end

      expect(response).to redirect_to(classroom_path(classroom))
    end

    it "redirects a monthly refresh before the last school day without picking a king" do
      classroom.update!(monthly_compliment_king_enabled: true)

      travel_to Time.zone.local(2026, 4, 20, 12, 0, 0) do
        expect(ComplimentKings::Pick).not_to receive(:call)

        post refresh_compliment_king_classroom_path(classroom), params: { period: "monthly" }, headers: turbo_headers
      end

      expect(response).to redirect_to(classroom_path(classroom))
    end

    it "rejects refresh for a disabled period" do
      post refresh_compliment_king_classroom_path(classroom), params: { period: "weekly" }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "rejects an unassigned school manager" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: classroom.school, user: manager)
      sign_in manager

      post refresh_compliment_king_classroom_path(classroom), params: { period: "daily" }

      expect(response).to redirect_to(root_path)
    end

    it "allows an assigned school manager" do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: classroom.school, user: manager)
      create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
      sign_in manager

      post refresh_compliment_king_classroom_path(classroom), params: { period: "daily" }, headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("오늘의 칭찬왕")
    end
  end
end
