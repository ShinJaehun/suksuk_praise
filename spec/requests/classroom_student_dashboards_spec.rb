require "rails_helper"

RSpec.describe "Classroom student dashboards", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:classroom) { create(:classroom, name: "대상 교실") }
  let(:student) { create(:user, :student, name: "대상 학생") }
  let(:teacher) { create(:user, :teacher) }

  before do
    create(:classroom_membership, classroom: classroom, user: student, role: "student")
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
  end

  it "shows a target student's weekly dashboard to the classroom teacher" do
    travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
      create(
        :compliment,
        classroom: classroom,
        receiver: student,
        given_at: Time.zone.local(2026, 4, 6, 10, 0, 0)
      )
      create(
        :user_coupon,
        classroom: classroom,
        user: student,
        issuance_basis: "manual",
        issued_at: Time.zone.local(2026, 4, 7, 10, 0, 0)
      )
      sign_in teacher

      get dashboard_classroom_student_path(classroom, student)
    end

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(response.body).to include(student.name)
    expect(response.body).to include(classroom.name)
    expect(response.body).to include("한눈에 보기")
    expect(response.body).not_to include("쿠폰 지급")
    expect(response.body).not_to include("쿠폰 뽑기")
    expect(response.body).not_to include("선택한 쿠폰 지급")
    expect(response.body).to include("2026.04.06 ~ 2026.04.10")
    expect(document.at_css('[data-summary="weekly-praise"]')["data-count"]).to eq("1")
    expect(document.at_css('[data-summary="weekly-issued-coupons"]')["data-count"]).to eq("1")
    expect(document.at_css('svg[aria-label="월요일부터 금요일까지 받은 칭찬과 쿠폰 활동 그래프"]')).to be_present
    expect(document.at_css('a[aria-label="이전 주 보기"]')["href"]).to eq(
      dashboard_classroom_student_path(classroom, student, week_offset: -1)
    )
    dashboard_navigation = document.at_css(%(a[href="#{dashboard_classroom_student_path(classroom, student)}"]))
    expect(dashboard_navigation["class"]).to include("border-blue-500")
  end

  it "supports week_offset for the target student dashboard" do
    sign_in teacher

    travel_to Time.zone.local(2026, 4, 8, 10, 0, 0) do
      get dashboard_classroom_student_path(classroom, student), params: { week_offset: -1 }
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("2026.03.30 ~ 2026.04.03")
  end

  it "allows an admin to view a target student dashboard" do
    sign_in create(:user, :admin)

    get dashboard_classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(student.name)
  end

  it "allows the student to view their own target dashboard" do
    sign_in student

    get dashboard_classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("한눈에 보기")
    expect(response.body).not_to include("학생 정보·PIN 수정")
    expect(response.body).not_to include("쿠폰 지급")
    expect(response.body).not_to include("쿠폰 뽑기")
    expect(response.body).not_to include("선택한 쿠폰 지급")
  end

  it "rejects another student" do
    other_student = create(:user, :student)
    create(:classroom_membership, classroom: classroom, user: other_student, role: "student")
    sign_in other_student

    get dashboard_classroom_student_path(classroom, student)

    expect(response).to redirect_to(root_path)
  end

  it "rejects a teacher outside the classroom" do
    sign_in create(:user, :teacher)

    get dashboard_classroom_student_path(classroom, student)

    expect(response).to redirect_to(root_path)
  end

  it "enforces the URL classroom boundary for a student with an inactive past membership" do
    past_classroom = create(:classroom, school: classroom.school)
    classroom.classroom_memberships.find_by!(user: student, role: "student").update!(status: "active")
    create(:classroom_membership, classroom: past_classroom, user: student, role: "student", status: "inactive")

    sign_in teacher
    get dashboard_classroom_student_path(past_classroom, student)
    expect(response).to redirect_to(root_path)

    past_teacher = create(:user, :teacher)
    create(:classroom_membership, classroom: past_classroom, user: past_teacher, role: "teacher")
    sign_in past_teacher
    get dashboard_classroom_student_path(past_classroom, student)
    expect(response).to have_http_status(:ok)

    sign_in create(:user, :admin)
    get dashboard_classroom_student_path(past_classroom, student)
    expect(response).to have_http_status(:ok)

    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: past_classroom.school, user: manager)
    sign_in manager
    get dashboard_classroom_student_path(past_classroom, student)
    expect(response).to redirect_to(root_path)

    sign_in student
    get dashboard_classroom_student_path(classroom, student)
    expect(response).to have_http_status(:ok)
    get dashboard_classroom_student_path(past_classroom, student)
    expect(response).to have_http_status(:not_found)
  end
end
