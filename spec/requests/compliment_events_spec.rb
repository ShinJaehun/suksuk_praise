require 'rails_helper'

RSpec.describe 'Compliment events', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:classroom) { create(:classroom, name: '햇살반') }
  let(:other_classroom) { create(:classroom, name: '달빛반') }
  let(:teacher) { create(:user, :teacher, name: '신재훈') }
  let(:student) { create(:user, :student, name: '김학생') }
  let(:other_student) { create(:user, :student, name: '박학생') }

  before do
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    create(:classroom_membership, classroom: classroom, user: student, role: 'student')
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: 'student')
  end

  around do |example|
    travel_to Time.zone.local(2026, 7, 24, 14, 0) do
      example.run
    end
  end

  def document
    Nokogiri::HTML(response.body)
  end

  def selected_value(selector)
    document.at_css(selector).at_css('option[selected]')['value']
  end

  def create_compliment_for(classroom:, receiver:, given_at:, giver: teacher, reason: nil, preset: nil)
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

  it 'uses the global event route while keeping nested compliment creation routes' do
    sign_in teacher

    get compliment_events_path

    expect(response).to have_http_status(:ok)
    expect do
      Rails.application.routes.recognize_path("/classrooms/#{classroom.id}/compliments", method: :get)
    end.to raise_error(ActionController::RoutingError)
    expect(new_classroom_compliment_path(classroom)).to eq("/classrooms/#{classroom.id}/compliments/new")
    expect(classroom_compliments_path(classroom)).to eq("/classrooms/#{classroom.id}/compliments")
    expect do
      Rails.application.routes.recognize_path('/compliments', method: :post)
    end.to raise_error(ActionController::RoutingError)
  end

  it 'redirects the legacy GET path to the new event URL while preserving query parameters' do
    sign_in teacher

    get "/compliments?classroom_id=#{classroom.id}&kind=custom"

    expect(response).to redirect_to("/compliment_events?classroom_id=#{classroom.id}&kind=custom")
  end

  it 'allows an admin to view compliments from multiple classrooms' do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '햇살반 칭찬')
    create_compliment_for(classroom: other_classroom, receiver: other_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '달빛반 칭찬')
    sign_in create(:user, :admin)

    get compliment_events_path

    expect(response.body).to include('햇살반')
    expect(response.body).to include('달빛반')
    expect(response.body).to include('햇살반 칭찬')
    expect(response.body).to include('달빛반 칭찬')
  end

  it 'shows only classrooms assigned to the teacher' do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '담당 교실 칭찬')
    create_compliment_for(classroom: other_classroom, receiver: other_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '외부 교실 칭찬')
    sign_in teacher

    get compliment_events_path

    expect(response.body).to include('담당 교실 칭찬')
    expect(response.body).not_to include('외부 교실 칭찬')
  end

  it 'allows a teacher assigned to multiple classrooms to view both assigned classroom compliments' do
    create(:classroom_membership, classroom: other_classroom, user: teacher, role: 'teacher')
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '첫 교실 칭찬')
    create_compliment_for(classroom: other_classroom, receiver: other_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '둘째 교실 칭찬')
    sign_in teacher

    get compliment_events_path

    expect(response.body).to include('첫 교실 칭찬')
    expect(response.body).to include('둘째 교실 칭찬')
  end

  it 'rejects students, teachers without classrooms, and school managers without teacher classroom membership' do
    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: classroom.school, user: manager)

    [student, create(:user, :teacher), manager].each do |user|
      sign_in user
      get compliment_events_path

      expect(response).to redirect_to(root_path)
      sign_out user
    end
  end

  it 'auto-selects the only classroom for a regular single-classroom teacher' do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '담당 교실 칭찬')
    create_compliment_for(classroom: other_classroom, receiver: other_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '외부 교실 칭찬')
    inactive_student = create(:user, :student, name: '비활성학생')
    create(:classroom_membership, classroom: classroom, user: inactive_student, role: 'student', status: 'inactive')
    sign_in teacher

    get compliment_events_path

    expect(response.body).to include('담당 교실 칭찬')
    expect(response.body).not_to include('외부 교실 칭찬')
    expect(document.at_css("select[name='classroom_id']")).to be_nil
    expect(response.body).to include('햇살반')

    student_select = document.at_css("select[name='student_membership_id']")
    expect(student_select['disabled']).to be_nil
    expect(student_select.text).to include('전체 학생')
    expect(student_select.text).to include('김학생')
    expect(student_select.text).to include('비활성학생')
    expect(student_select.text).not_to include('박학생')
  end

  it 'ignores a manipulated classroom id for a regular single-classroom teacher' do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '담당 교실 칭찬')
    create_compliment_for(classroom: other_classroom, receiver: other_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '외부 교실 칭찬')
    sign_in teacher

    get compliment_events_path(classroom_id: other_classroom.id)

    expect(response.body).to include('담당 교실 칭찬')
    expect(response.body).not_to include('외부 교실 칭찬')
  end

  it 'filters by an accessible classroom and does not expose inaccessible classroom ids for admins' do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '담당 교실 칭찬')
    create_compliment_for(classroom: other_classroom, receiver: other_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '외부 교실 칭찬')
    sign_in create(:user, :admin)

    get compliment_events_path(classroom_id: classroom.id)

    expect(response.body).to include('담당 교실 칭찬')
    expect(response.body).not_to include('외부 교실 칭찬')
  end

  it 'hides the student filter until a classroom is selected' do
    create(:classroom_membership, classroom: other_classroom, user: teacher, role: 'teacher')
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '전체 조회 칭찬')
    sign_in teacher

    get compliment_events_path

    expect(document.at_css("select[name='student_membership_id']")).to be_nil
    expect(response.body).not_to include('교실을 먼저 선택하세요')
    expect(response.body).not_to include('햇살반 · 김학생')
    expect(response.body).to include('data-controller="compliment-event-filters"')
    expect(response.body).to include('change-&gt;compliment-event-filters#classroomChanged')
    expect(response.body).to include('전체 조회 칭찬')

    get compliment_events_path(classroom_id: classroom.id)

    student_select = document.at_css("select[name='student_membership_id']")
    expect(student_select).not_to be_nil
    expect(student_select['disabled']).to be_nil
    expect(student_select.text).to include('김학생')
    expect(student_select.text).not_to include('박학생')
  end

  it 'ignores a stale student membership id when no classroom is selected' do
    create(:classroom_membership, classroom: other_classroom, user: teacher, role: 'teacher')
    same_classroom_student = create(:user, :student, name: '다른학생')
    membership = create(:classroom_membership, classroom: classroom, user: same_classroom_student, role: 'student')
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '기본 학생 칭찬')
    create_compliment_for(classroom: classroom, receiver: same_classroom_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '다른 학생 칭찬')
    sign_in teacher

    get compliment_events_path(student_membership_id: membership.id)

    expect(document.at_css("select[name='student_membership_id']")).to be_nil
    expect(response.body).to include('기본 학생 칭찬')
    expect(response.body).to include('다른 학생 칭찬')
  end

  it 'filters by student membership without classroom_id for a regular single-classroom teacher' do
    same_classroom_student = create(:user, :student, name: '다른학생')
    membership = create(:classroom_membership, classroom: classroom, user: same_classroom_student, role: 'student')
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: '기본 학생 칭찬')
    create_compliment_for(classroom: classroom, receiver: same_classroom_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '다른 학생 칭찬')
    sign_in teacher

    get compliment_events_path(student_membership_id: membership.id)

    expect(response.body).not_to include('기본 학생 칭찬')
    expect(response.body).to include('다른 학생 칭찬')
  end

  it 'filters by selected classroom student membership and includes inactive students in the options' do
    inactive_student = create(:user, :student, name: '비활성학생')
    inactive_membership = create(:classroom_membership, classroom: classroom, user: inactive_student, role: 'student',
                                                        status: 'inactive')
    same_classroom_student = create(:user, :student, name: '다른학생')
    other_membership = create(:classroom_membership, classroom: classroom, user: same_classroom_student,
                                                     role: 'student')

    create_compliment_for(classroom: classroom, receiver: inactive_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: '비활성 과거 칭찬')
    create_compliment_for(classroom: classroom, receiver: same_classroom_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '다른 학생 칭찬')
    sign_in teacher

    get compliment_events_path(classroom_id: classroom.id, student_membership_id: inactive_membership.id)

    expect(response.body).to include('비활성학생')
    expect(response.body).to include('비활성 과거 칭찬')
    expect(response.body).not_to include('다른 학생 칭찬')

    get compliment_events_path(classroom_id: classroom.id)

    student_select = document.at_css("select[name='student_membership_id']")
    expect(student_select['disabled']).to be_nil
    expect(student_select.text).to include('전체 학생')
    expect(student_select.text).to include('김학생')
    expect(student_select.text).to include('비활성학생')
    expect(student_select.text).to include(other_membership.user.name)
    expect(student_select.text).not_to include('햇살반 · 김학생')
  end

  it 'does not expose records through another classroom, teacher, or missing membership id' do
    other_membership = ClassroomMembership.find_by!(classroom: other_classroom, user: other_student, role: 'student')
    teacher_membership = ClassroomMembership.find_by!(classroom: classroom, user: teacher, role: 'teacher')
    create_compliment_for(classroom: other_classroom, receiver: other_student,
                          given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: '외부 학생 칭찬')
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 11),
                          reason: '담당 학생 칭찬')
    sign_in teacher

    [other_membership.id, teacher_membership.id, '999999', 'invalid'].each do |membership_id|
      get compliment_events_path(classroom_id: classroom.id, student_membership_id: membership_id)

      expect(response.body).not_to include('외부 학생 칭찬')
      expect(response.body).not_to include('담당 학생 칭찬')
    end
  end

  it 'shows the classroom select for admins and enables students after classroom selection' do
    sign_in create(:user, :admin)

    get compliment_events_path

    expect(document.at_css("select[name='classroom_id']")).not_to be_nil
    expect(document.at_css("select[name='student_membership_id']")).to be_nil
    expect(response.body).not_to include('교실을 먼저 선택하세요')

    get compliment_events_path(classroom_id: other_classroom.id)

    student_select = document.at_css("select[name='student_membership_id']")
    expect(student_select).not_to be_nil
    expect(student_select['disabled']).to be_nil
    expect(student_select.text).to include('박학생')
    expect(student_select.text).not_to include('김학생')
  end

  it 'does not grant school managers school-wide compliment logs' do
    manager = create(:user, :teacher)
    manager_classroom = create(:classroom, name: '매니저담당반', school: classroom.school)
    manager_student = create(:user, :student, name: '담당학생')
    create(:school_membership, :manager, school: classroom.school, user: manager)
    create(:classroom_membership, classroom: manager_classroom, user: manager, role: 'teacher')
    create(:classroom_membership, classroom: manager_classroom, user: manager_student, role: 'student')
    create_compliment_for(classroom: classroom, receiver: student, giver: teacher,
                          given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: '학교 전체 칭찬')
    create_compliment_for(classroom: manager_classroom, receiver: manager_student, giver: manager,
                          given_at: Time.zone.local(2026, 7, 24, 13, 11), reason: '담당 교실 칭찬')
    sign_in manager

    get compliment_events_path

    expect(document.at_css("select[name='classroom_id']")).not_to be_nil
    expect(response.body).to include('담당 교실 칭찬')
    expect(response.body).not_to include('학교 전체 칭찬')
    expect(response.body).not_to include('햇살반')
  end

  it 'filters by compliment kind using the reason snapshot' do
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 10),
                          reason: nil)
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 11),
                          reason: '친구를 도움')
    create_compliment_for(classroom: classroom, receiver: student, given_at: Time.zone.local(2026, 7, 24, 13, 12),
                          reason: 'snapshot만 있는 칭찬')
    Compliment.last.update!(compliment_preset: nil)
    sign_in teacher

    get compliment_events_path(kind: 'general')
    expect(response.body).not_to include('친구를 도움')
    expect(response.body).not_to include('snapshot만 있는 칭찬')

    get compliment_events_path(kind: 'custom')
    expect(response.body).to include('친구를 도움')
    expect(response.body).to include('snapshot만 있는 칭찬')

    get compliment_events_path(kind: 'unknown')
    expect(response.body).to include('친구를 도움')
    expect(response.body).to include('김학생')
  end

  it 'shows classroom, receiver, giver, snapshot reason, and stable latest ordering' do
    preset = create(:compliment_preset, user: teacher, title: '다른 친구를 위해 봉사함')
    older = create_compliment_for(classroom: classroom, receiver: student,
                                  given_at: Time.zone.local(2026, 7, 24, 13, 0), reason: '오래된 칭찬')
    first_same_time = create_compliment_for(classroom: classroom, receiver: student,
                                            given_at: Time.zone.local(2026, 7, 24, 13, 10), reason: '같은 시각 첫 번째')
    second_same_time = create_compliment_for(classroom: classroom, receiver: student,
                                             given_at: first_same_time.given_at, reason: preset.title, preset: preset)
    preset.update!(title: '수정된 문구', active: false)
    sign_in teacher

    get compliment_events_path

    body = response.body
    expect(body).to include('햇살반')
    expect(body).to include('김학생')
    expect(body).to include('신재훈')
    expect(body).to include('다른 친구를 위해 봉사함')
    expect(body).not_to include('수정된 문구')
    expect(body.index(second_same_time.reason)).to be < body.index(first_same_time.reason)
    expect(body.index(first_same_time.reason)).to be < body.index(older.reason)
  end

  it 'paginates on the event URL and keeps valid query parameters' do
    create(:classroom_membership, classroom: other_classroom, user: teacher, role: 'teacher')
    11.times do |index|
      create_compliment_for(
        classroom: classroom,
        receiver: student,
        given_at: Time.zone.local(2026, 7, 24, 13, index),
        reason: "페이지 칭찬 #{index}"
      )
    end
    membership = ClassroomMembership.find_by!(classroom: classroom, user: student, role: 'student')
    sign_in teacher

    get compliment_events_path(
      classroom_id: classroom.id,
      student_membership_id: membership.id,
      period: 'custom',
      start_date: '2026-07-24',
      end_date: '2026-07-24',
      kind: 'custom',
      sort: 'given_at_asc'
    )

    expect(response.body).to include('페이지 칭찬 0')
    expect(response.body).not_to include('페이지 칭찬 10')
    expect(response.body).to include('event-log-pagination')
    expect(response.body).to include('/compliment_events')
    expect(response.body).not_to include('/compliments?')
    expect(response.body).to include("classroom_id=#{classroom.id}")
    expect(response.body).to include("student_membership_id=#{membership.id}")
    expect(response.body).to include('period=custom')
    expect(response.body).to include('start_date=2026-07-24')
    expect(response.body).to include('end_date=2026-07-24')
    expect(response.body).to include('kind=custom')
    expect(response.body).to include('sort=given_at_asc')

    get compliment_events_path(
      classroom_id: classroom.id,
      student_membership_id: membership.id,
      period: 'custom',
      start_date: '2026-07-24',
      end_date: '2026-07-24',
      kind: 'custom',
      sort: 'given_at_asc',
      page: 2
    )

    expect(response.body).to include('페이지 칭찬 10')
  end

  it 'resets filters to the event URL' do
    sign_in teacher

    get compliment_events_path(classroom_id: classroom.id, kind: 'custom')

    reset_link = document.at_css(
      "form[action='#{compliment_events_path}'] a[href='#{compliment_events_path}']"
    )

    expect(reset_link).not_to be_nil
    expect(reset_link.text).to include('필터 초기화')

    get compliment_events_path

    expect(selected_value("select[name='period']")).to eq('last_7_days')
    expect(selected_value("select[name='sort']")).to eq('given_at_desc')
  end

  it 'filters by period using given_at and falls back safely' do
    in_range = create_compliment_for(
      classroom: classroom,
      receiver: student,
      given_at: Time.zone.local(2026, 7, 23, 13, 10),
      reason: '최근 7일 칭찬'
    )
    create_compliment_for(
      classroom: classroom,
      receiver: student,
      given_at: Time.zone.local(2026, 7, 10, 13, 10),
      reason: '최근 30일 칭찬'
    )
    create_compliment_for(
      classroom: classroom,
      receiver: student,
      given_at: Time.zone.local(2026, 6, 1, 13, 10),
      reason: '오래된 칭찬'
    )
    in_range.update_columns(created_at: Time.zone.local(2026, 6, 1, 13, 10))
    sign_in teacher

    get compliment_events_path
    expect(response.body).to include('최근 7일 칭찬')
    expect(response.body).not_to include('최근 30일 칭찬')

    get compliment_events_path(period: 'last_30_days')
    expect(response.body).to include('최근 30일 칭찬')
    expect(response.body).not_to include('오래된 칭찬')

    get compliment_events_path(period: 'all_time')
    expect(response.body).to include('오래된 칭찬')

    get compliment_events_path(period: 'unknown')
    expect(selected_value("select[name='period']")).to eq('last_7_days')
    expect(response.body).to include('최근 7일 칭찬')
    expect(response.body).not_to include('최근 30일 칭찬')
  end

  it 'supports today, this week, this month, and custom compliment periods' do
    create_compliment_for(classroom: classroom, receiver: student,
                          given_at: Time.zone.local(2026, 7, 24, 9, 0), reason: '오늘 칭찬')
    create_compliment_for(classroom: classroom, receiver: student,
                          given_at: Time.zone.local(2026, 7, 20, 9, 0), reason: '이번 주 칭찬')
    create_compliment_for(classroom: classroom, receiver: student,
                          given_at: Time.zone.local(2026, 7, 1, 9, 0), reason: '이번 달 칭찬')
    create_compliment_for(classroom: classroom, receiver: student,
                          given_at: Time.zone.local(2026, 6, 30, 9, 0), reason: '지난 달 칭찬')
    sign_in teacher

    get compliment_events_path(period: 'today')
    expect(response.body).to include('오늘 칭찬')
    expect(response.body).not_to include('이번 주 칭찬')

    get compliment_events_path(period: 'this_week')
    expect(response.body).to include('이번 주 칭찬')
    expect(response.body).not_to include('이번 달 칭찬')

    get compliment_events_path(period: 'this_month')
    expect(response.body).to include('이번 달 칭찬')
    expect(response.body).not_to include('지난 달 칭찬')

    get compliment_events_path(period: 'custom', start_date: '2026-07-20', end_date: '2026-07-24')
    expect(response.body).to include('오늘 칭찬')
    expect(response.body).to include('이번 주 칭찬')
    expect(response.body).not_to include('이번 달 칭찬')

    get compliment_events_path(period: 'custom', start_date: 'invalid', end_date: '2026-07-24')
    expect(response).to have_http_status(:ok)
  end

  it 'sorts by compliment given_at with stable id tie-breakers' do
    older = create_compliment_for(classroom: classroom, receiver: student,
                                  given_at: Time.zone.local(2026, 7, 24, 12, 0), reason: '오래된 정렬')
    same_time_first = create_compliment_for(classroom: classroom, receiver: student,
                                            given_at: Time.zone.local(2026, 7, 24, 13, 0), reason: '같은 시각 첫 정렬')
    same_time_second = create_compliment_for(classroom: classroom, receiver: student,
                                             given_at: same_time_first.given_at, reason: '같은 시각 둘째 정렬')
    sign_in teacher

    get compliment_events_path(sort: 'given_at_desc')
    body = response.body
    expect(body.index(same_time_second.reason)).to be < body.index(same_time_first.reason)
    expect(body.index(same_time_first.reason)).to be < body.index(older.reason)

    get compliment_events_path(sort: 'given_at_asc')
    body = response.body
    expect(body.index(older.reason)).to be < body.index(same_time_first.reason)
    expect(body.index(same_time_first.reason)).to be < body.index(same_time_second.reason)

    get compliment_events_path(sort: 'unknown')
    expect(selected_value("select[name='sort']")).to eq('given_at_desc')
  end

  it 'shows an empty state when no compliments match' do
    sign_in teacher

    get compliment_events_path(kind: 'custom')

    expect(response.body).to include('표시할 칭찬 로그가 없습니다.')
  end

  it 'shows the compliment log link only to admins and teachers with assigned classrooms' do
    create(:compliment_preset, user: teacher, title: '친구와 사이좋게 지냄')

    [teacher, create(:user, :admin)].each do |user|
      sign_in user
      get classrooms_path

      expect(response.body).to include(compliment_events_path)
      expect(response.body).not_to include('/compliments')
      sign_out user
    end

    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: classroom.school, user: manager)

    [student, create(:user, :teacher), manager].each do |user|
      sign_in user
      get root_path
      follow_redirect! if response.redirect?

      expect(response.body).not_to include(compliment_events_path)
      sign_out user
    end
  end

  it 'shows the frequent compliment link to teachers and admins without classroom inference' do
    [teacher, create(:user, :teacher), create(:user, :admin)].each do |user|
      sign_in user
      get root_path
      follow_redirect! if response.redirect?

      expect(response.body).to include(compliment_templates_path)
      expect(response.body).to include('자주 쓰는 칭찬')
      expect(response.body).not_to include('/compliment_presets')
      sign_out user
    end

    sign_in student
    get root_path
    follow_redirect! if response.redirect?

    expect(response.body).not_to include('자주 쓰는 칭찬')
    expect(response.body).not_to include(compliment_templates_path)
  end

  it 'keeps the custom compliment button on classroom cards when active presets exist' do
    create(:compliment_preset, user: teacher, title: '친구와 사이좋게 지냄')
    sign_in teacher

    get classroom_path(classroom)

    expect(response.body).to include(I18n.t('ui.buttons.custom_compliment'))
    expect(response.body).not_to include("/classrooms/#{classroom.id}/compliment_templates")
    expect(response.body).not_to include("/classrooms/#{classroom.id}/compliment_presets")
  end
end
