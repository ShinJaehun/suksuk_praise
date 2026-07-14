require "rails_helper"

RSpec.describe "Classrooms compliment kings", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include ActionView::RecordIdentifier

  describe "GET /classrooms/:id" do
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }

    before do
      sign_in teacher
    end

    def refresh_button_for(document, period)
      frame_id = dom_id(classroom, :"compliment_king_#{period}")
      action = refresh_compliment_king_classroom_path(classroom, period: period)

      document.css("form").find { |form|
        form["action"] == action &&
          form.at_css(%(button[aria-controls="#{frame_id}"]))
      }&.at_css(%(button[aria-controls="#{frame_id}"]))
    end

    it "shows only enabled period buttons on initial load" do
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

      get classroom_path(classroom)

      document = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:ok)
      expect(refresh_button_for(document, "daily")).to be_present
      expect(refresh_button_for(document, "weekly")).to be_nil
      expect(refresh_button_for(document, "monthly")).to be_nil
      expect(response.body).not_to include("쿠폰 뽑기")
      expect(response.body).not_to include("선택한 쿠폰 지급")
      expect(response.body).to include("href=\"#{classroom_student_path(classroom, student)}\"")
    end

    it "shows the weekly king button only when weekly is enabled" do
      classroom.update!(weekly_compliment_king_enabled: true)
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

      travel_to Time.zone.local(2026, 4, 10, 10, 0, 0) do
        get classroom_path(classroom)
      end

      document = Nokogiri::HTML(response.body)

      expect(refresh_button_for(document, "daily")).to be_present
      expect(refresh_button_for(document, "weekly")).to be_present
      expect(refresh_button_for(document, "monthly")).to be_nil
    end

    it "shows the monthly king button only when monthly is enabled" do
      classroom.update!(monthly_compliment_king_enabled: true)
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.zone.local(2026, 4, 7, 10, 0, 0))

      travel_to Time.zone.local(2026, 4, 30, 10, 0, 0) do
        get classroom_path(classroom)
      end

      document = Nokogiri::HTML(response.body)

      expect(refresh_button_for(document, "daily")).to be_present
      expect(refresh_button_for(document, "weekly")).to be_nil
      expect(refresh_button_for(document, "monthly")).to be_present
    end

    it "renders compliment king toggle wiring for each enabled period" do
      classroom.update!(weekly_compliment_king_enabled: true, monthly_compliment_king_enabled: true)

      travel_to Time.zone.local(2026, 7, 31, 10, 0, 0) do
        get classroom_path(classroom)
      end

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('[data-controller="compliment-king-toggle"]')).to be_present

      %w[daily weekly monthly].each do |period|
        frame_id = dom_id(classroom, :"compliment_king_#{period}")
        button = refresh_button_for(document, period)
        frame = document.at_css(%(turbo-frame##{frame_id}))

        expect(button).to be_present
        expect(button["aria-expanded"]).to eq("false")
        expect(button.ancestors("form").first["data-action"]).to eq("submit->compliment-king-toggle#submit")
        expect(frame).to be_present
        expect(frame.key?("hidden")).to eq(true)
      end
    end

    it "hides weekly and monthly refresh buttons before the last school day without adding guidance text" do
      classroom.update!(weekly_compliment_king_enabled: true, monthly_compliment_king_enabled: true)

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        get classroom_path(classroom)
      end

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(refresh_button_for(document, "daily")).to be_present
      expect(refresh_button_for(document, "weekly")).to be_nil
      expect(refresh_button_for(document, "monthly")).to be_nil
      expect(response.body).not_to include("마지막 운영일")
      expect(response.body).not_to include("오늘은 휴일입니다")
    end

    it "keeps the daily refresh button visible on a school closure" do
      create(:school_closure, school: classroom.school, starts_on: Date.new(2026, 4, 8), ends_on: Date.new(2026, 4, 8))

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        get classroom_path(classroom)
      end

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(refresh_button_for(document, "daily")).to be_present
    end

    it "keeps enabled weekly refresh behavior for classrooms without a school" do
      classroom.update!(school: nil, weekly_compliment_king_enabled: true)

      travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
        get classroom_path(classroom)
      end

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(refresh_button_for(document, "weekly")).to be_present
    end

    it "shows today's compliment count on student cards instead of total points" do
      student.update!(points: 9)

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: 1.day.ago)
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.current)

        get classroom_path(classroom)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("오늘 칭찬")
      expect(response.body).not_to include("칭찬(포인트)")
      expect(response.body).to match(/오늘 칭찬.*text-2xl[^>]*>1<\/div>/m)
    end

    it "shows active students and hides inactive students on the classroom page" do
      inactive_student = create(:user, :student, name: "비활성 학생")
      create(:classroom_membership, user: inactive_student, classroom: classroom, role: "student", status: "inactive")

      get classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(student.name)
      expect(response.body).not_to include(inactive_student.name)
    end
  end
end
