require "rails_helper"

RSpec.describe "Compliments#index", type: :request do
  let(:classroom) { create(:classroom, name: "햇살반") }
  let(:other_classroom) { create(:classroom, name: "달빛반") }
  let(:teacher) { create(:user, :teacher, name: "신재훈") }
  let(:student) { create(:user, :student, name: "김학생") }
  let(:other_student) { create(:user, :student, name: "박학생") }

  before do
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    create(:classroom_membership, classroom: classroom, user: student, role: "student")
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: "student")
  end

  def document
    Nokogiri::HTML(response.body)
  end

  def create_compliment_for(classroom:, receiver:, giver: teacher, given_at:, reason: nil, preset: nil)
    create(
      :compliment,
      classroom: classroom,
      giver: giver,
      receiver: receiver,
      given_at: given_at,
      compliment_preset: preset,
      reason: reason
    )
  end

  it "uses the global index route while keeping nested compliment creation routes" do
    sign_in teacher

    get compliments_path

    expect(response).to have_http_status(:ok)
    expect {
      Rails.application.routes.recognize_path("/classrooms/#{classroom.id}/compliments", method: :get)
    }.to raise_error(ActionController::RoutingError)
    expect(new_classroom_compliment_path(classroom)).to eq("/classrooms/#{classroom.id}/compliments/new")
    expect(classroom_compliments_path(classroom)).to eq("/classrooms/#{classroom.id}/compliments")
  end

  it "allows an admin to view compliments from multiple classrooms" do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: "햇살반 칭찬")
    create_compliment_for(classroom: other_classroom, receiver: other_student, given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: "달빛반 칭찬")
    sign_in create(:user, :admin)

    get compliments_path

    expect(response.body).to include("햇살반")
    expect(response.body).to include("달빛반")
    expect(response.body).to include("햇살반 칭찬")
    expect(response.body).to include("달빛반 칭찬")
  end

  it "shows only classrooms assigned to the teacher" do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: "담당 교실 칭찬")
    create_compliment_for(classroom: other_classroom, receiver: other_student, given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: "외부 교실 칭찬")
    sign_in teacher

    get compliments_path

    expect(response.body).to include("담당 교실 칭찬")
    expect(response.body).not_to include("외부 교실 칭찬")
  end

  it "allows a teacher assigned to multiple classrooms to view both assigned classroom compliments" do
    create(:classroom_membership, classroom: other_classroom, user: teacher, role: "teacher")
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: "첫 교실 칭찬")
    create_compliment_for(classroom: other_classroom, receiver: other_student, given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: "둘째 교실 칭찬")
    sign_in teacher

    get compliments_path

    expect(response.body).to include("첫 교실 칭찬")
    expect(response.body).to include("둘째 교실 칭찬")
  end

  it "rejects students, teachers without classrooms, and school managers without teacher classroom membership" do
    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: classroom.school, user: manager)

    [student, create(:user, :teacher), manager].each do |user|
      sign_in user
      get compliments_path

      expect(response).to redirect_to(root_path)
      sign_out user
    end
  end

  it "filters by an accessible classroom and does not expose inaccessible classroom ids" do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: "담당 교실 칭찬")
    create_compliment_for(classroom: other_classroom, receiver: other_student, given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: "외부 교실 칭찬")
    sign_in teacher

    get compliments_path(classroom_id: classroom.id)

    expect(response.body).to include("담당 교실 칭찬")
    expect(response.body).not_to include("외부 교실 칭찬")

    get compliments_path(classroom_id: other_classroom.id)

    expect(response.body).not_to include("담당 교실 칭찬")
    expect(response.body).not_to include("외부 교실 칭찬")
  end

  it "filters by student membership and includes inactive students in the options" do
    inactive_student = create(:user, :student, name: "비활성학생")
    inactive_membership = create(:classroom_membership, classroom: classroom, user: inactive_student, role: "student", status: "inactive")
    same_classroom_student = create(:user, :student, name: "다른학생")
    other_membership = create(:classroom_membership, classroom: classroom, user: same_classroom_student, role: "student")

    create_compliment_for(classroom: classroom, receiver: inactive_student, given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: "비활성 과거 칭찬")
    create_compliment_for(classroom: classroom, receiver: same_classroom_student, given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: "다른 학생 칭찬")
    sign_in teacher

    get compliments_path(student_membership_id: inactive_membership.id)

    expect(response.body).to include("비활성학생")
    expect(response.body).to include("비활성 과거 칭찬")
    expect(response.body).not_to include("다른 학생 칭찬")

    get compliments_path(classroom_id: classroom.id)

    expect(response.body).to include("비활성학생")
    expect(response.body).to include(other_membership.user.name)
  end

  it "labels student options with classroom names when all classrooms are selected" do
    create(:classroom_membership, classroom: other_classroom, user: teacher, role: "teacher")
    sign_in teacher

    get compliments_path

    expect(response.body).to include("햇살반 · 김학생")
    expect(response.body).to include("달빛반 · 박학생")
  end

  it "does not expose records through another classroom student membership id" do
    other_membership = ClassroomMembership.find_by!(classroom: other_classroom, user: other_student, role: "student")
    create_compliment_for(classroom: other_classroom, receiver: other_student, given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: "외부 학생 칭찬")
    sign_in teacher

    get compliments_path(student_membership_id: other_membership.id)

    expect(response.body).not_to include("외부 학생 칭찬")
  end

  it "filters by compliment kind using the reason snapshot" do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: nil)
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: "친구를 도움")
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 12), reason: "snapshot만 있는 칭찬")
    Compliment.last.update!(compliment_preset: nil)
    sign_in teacher

    get compliments_path(kind: "general")
    expect(response.body).not_to include("친구를 도움")
    expect(response.body).not_to include("snapshot만 있는 칭찬")

    get compliments_path(kind: "custom")
    expect(response.body).to include("친구를 도움")
    expect(response.body).to include("snapshot만 있는 칭찬")

    get compliments_path(kind: "unknown")
    expect(response.body).to include("친구를 도움")
    expect(response.body).to include("김학생")
  end

  it "shows classroom, receiver, giver, snapshot reason, and stable latest ordering" do
    preset = create(:compliment_preset, user: teacher, title: "다른 친구를 위해 봉사함")
    older = create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 0), reason: "오래된 칭찬")
    first_same_time = create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: "같은 시각 첫 번째")
    second_same_time = create_compliment_for(classroom: classroom, receiver: student, given_at: first_same_time.given_at, reason: preset.title, preset: preset)
    preset.update!(title: "수정된 문구", active: false)
    sign_in teacher

    get compliments_path

    body = response.body
    expect(body).to include("햇살반")
    expect(body).to include("김학생")
    expect(body).to include("신재훈")
    expect(body).to include("다른 친구를 위해 봉사함")
    expect(body).not_to include("수정된 문구")
    expect(body.index(second_same_time.reason)).to be < body.index(first_same_time.reason)
    expect(body.index(first_same_time.reason)).to be < body.index(older.reason)
  end

  it "paginates and keeps classroom, student, and kind query parameters" do
    11.times do |index|
      create_compliment_for(
        classroom: classroom,
        receiver: student,
        given_at: Time.zone.local(2026, 7, 24, 13, index),
        reason: "페이지 칭찬 #{index}"
      )
    end
    membership = ClassroomMembership.find_by!(classroom: classroom, user: student, role: "student")
    sign_in teacher

    get compliments_path(classroom_id: classroom.id, student_membership_id: membership.id, kind: "custom")

    expect(response.body).to include("페이지 칭찬 10")
    expect(response.body).not_to include("페이지 칭찬 0")
    expect(response.body).to include("coupon-events-pagy")
    expect(response.body).to include("classroom_id=#{classroom.id}")
    expect(response.body).to include("student_membership_id=#{membership.id}")
    expect(response.body).to include("kind=custom")

    get compliments_path(classroom_id: classroom.id, student_membership_id: membership.id, kind: "custom", page: 2)

    expect(response.body).to include("페이지 칭찬 0")
  end

  it "shows an empty state when no compliments match" do
    sign_in teacher

    get compliments_path(kind: "custom")

    expect(response.body).to include("표시할 칭찬 로그가 없습니다.")
  end

  it "shows the compliment log link only to admins and teachers with assigned classrooms" do
    create(:compliment_preset, user: teacher, title: "친구와 사이좋게 지냄")

    [teacher, create(:user, :admin)].each do |user|
      sign_in user
      get classrooms_path

      expect(response.body).to include(compliments_path)
      sign_out user
    end

    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: classroom.school, user: manager)

    [student, create(:user, :teacher), manager].each do |user|
      sign_in user
      get root_path
      follow_redirect! if response.redirect?

      expect(response.body).not_to include(compliments_path)
      sign_out user
    end
  end

  it "shows the frequent compliment link to teachers and admins without classroom inference" do
    [teacher, create(:user, :teacher), create(:user, :admin)].each do |user|
      sign_in user
      get root_path
      follow_redirect! if response.redirect?

      expect(response.body).to include(compliment_presets_path)
      expect(response.body).to include("자주 쓰는 칭찬")
      sign_out user
    end

    sign_in student
    get root_path
    follow_redirect! if response.redirect?

    expect(response.body).not_to include("자주 쓰는 칭찬")
    expect(response.body).not_to include(compliment_presets_path)
  end

  it "keeps the custom compliment button on classroom cards when active presets exist" do
    create(:compliment_preset, user: teacher, title: "친구와 사이좋게 지냄")
    sign_in teacher

    get classroom_path(classroom)

    expect(response.body).to include(I18n.t("ui.buttons.custom_compliment"))
    expect(response.body).not_to include("/classrooms/#{classroom.id}/compliment_presets")
  end
end
