require 'rails_helper'

RSpec.describe 'School workspaces', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:school) { create(:school, name: '새싹초등학교') }
  let!(:other_school) { create(:school, name: '다른초등학교') }
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user, :teacher) }
  let(:manager) { create(:user, :teacher) }

  before do
    create(:school_membership, school: school, user: member)
    create(:school_membership, :manager, school: school, user: manager)
  end

  it 'allows an admin to view every school workspace and manage closures' do
    sign_in admin

    get school_path(other_school)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(other_school.name)
    expect(response.body).to include(school_school_closures_path(other_school))
  end

  it 'shows every school in the admin index' do
    sign_in admin

    get schools_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(school.name, other_school.name)
    expect(response.body).not_to include('translation missing')
  end

  it 'redirects a member or manager index to their only school without exposing others' do
    [member, manager].each do |teacher|
      sign_in teacher
      get schools_path
      expect(response).to redirect_to(school_path(school))
      expect(response.body).not_to include(other_school.name)
    end
  end

  it 'allows members and managers to view only their school' do
    [member, manager].each do |teacher|
      sign_in teacher
      get school_path(school)
      expect(response).to have_http_status(:ok)

      get school_path(other_school)
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'hides management actions from a member and shows them to a manager' do
    closure = create(:school_closure, school: school)

    sign_in member
    get school_path(school)
    expect(response.body).not_to include(new_school_school_closure_path(school))
    expect(response.body).not_to include(edit_school_school_closure_path(school, closure))
    expect(response.body).not_to include('data-controller="school-closure-picker"')

    sign_in manager
    get school_path(school)
    expect(response.body).to include(school_school_closures_path(school))
    expect(response.body).to include(edit_school_school_closure_path(school, closure))
    expect(response.body).to include('data-controller="school-closure-picker"')
    expect(response.body).not_to include('translation missing')
  end

  it 'renders the requested monthly closure calendar with navigation and markers' do
    create(:school_closure, school: school, name: '여름방학', starts_on: Date.new(2026, 7, 28),
                            ends_on: Date.new(2026, 8, 4))
    create(:public_holiday, date: Date.new(2026, 8, 3), name: '대체공휴일')
    sign_in manager

    get school_path(school, month: '2026-08')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('2026년 8월')
    expect(response.body).to include(school_path(school, month: '2026-07'))
    expect(response.body).to include(school_path(school, month: '2026-09'))
    expect(response.body).to include('여름방학')
    expect(response.body).to include('공식 공휴일: 대체공휴일')
    expect(response.body).to include('학교 휴일: 여름방학')
  end

  it 'marks weekend calendar cells and headers without hiding holiday states' do
    create(:school_closure, school: school, name: '여름방학', starts_on: Date.new(2026, 8, 1),
                            ends_on: Date.new(2026, 8, 1))
    create(:public_holiday, date: Date.new(2026, 8, 2), name: '대체공휴일')
    sign_in manager

    get school_path(school, month: '2026-08')

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    saturday = calendar_day(document, Date.new(2026, 8, 1))
    sunday = calendar_day(document, Date.new(2026, 8, 2))
    monday = calendar_day(document, Date.new(2026, 8, 3))

    expect(saturday["class"]).to include("school-closure-calendar__day--saturday")
    expect(saturday["class"]).to include("school-closure-calendar__day--school-closure")
    expect(sunday["class"]).to include("school-closure-calendar__day--sunday")
    expect(sunday["class"]).to include("school-closure-calendar__day--public-holiday")
    expect(monday["class"]).not_to include("school-closure-calendar__day--saturday")
    expect(monday["class"]).not_to include("school-closure-calendar__day--sunday")

    weekday_headers = document.css(".school-closure-calendar__weekday")
    expect(weekday_headers.first["class"]).to include("school-closure-calendar__weekday--sunday")
    expect(weekday_headers.last["class"]).to include("school-closure-calendar__weekday--saturday")
  end

  it 'falls back to the current month when the month query is missing or invalid' do
    sign_in manager

    travel_to Time.zone.local(2026, 7, 14, 10, 0, 0) do
      get school_path(school)
      expect(response.body).to include('2026년 7월')

      get school_path(school, month: '2026-13')
      expect(response.body).to include('2026년 7월')

      get school_path(school, month: 'bad')
      expect(response.body).to include('2026년 7월')
    end
  end

  it 'shows read-only members the calendar without write controls' do
    create(:school_closure, school: school, name: '재량휴업일', starts_on: Date.new(2026, 7, 14),
                            ends_on: Date.new(2026, 7, 14))
    create(:public_holiday, date: Date.new(2026, 7, 14), name: '공휴일')
    sign_in member

    get school_path(school, month: '2026-07')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('2026년 7월', '학교 휴일: 재량휴업일', '공식 공휴일: 공휴일')
    expect(response.body).not_to include('data-action="school-closure-picker#selectDate"')
    expect(response.body).not_to include('data-controller="school-closure-picker"')
    expect(response.body).not_to include(school_school_closures_path(school))
  end

  it 'shows school classrooms and teachers while limiting manager controls to admin' do
    classroom = create(:classroom, school: school)
    create(:classroom_membership, classroom: classroom, user: member, role: :teacher)

    [member, manager].each do |teacher|
      sign_in teacher
      get school_path(school)
      expect(response.body).to include(classroom.name, member.name)
      expect(response.body).not_to include(admin_school_school_managers_path(school))
    end

    sign_in admin
    get school_path(school)
    expect(response.body).to include(admin_school_school_managers_path(school))
  end

  it 'links classrooms only when the viewer can open them' do
    assigned_classroom = create(:classroom, school: school, name: '담당 학급')
    unassigned_classroom = create(:classroom, school: school, name: '미담당 학급')
    create(:classroom_membership, classroom: assigned_classroom, user: member, role: :teacher)

    sign_in member
    get school_path(school)
    expect(response.body).to include(assigned_classroom.name, unassigned_classroom.name)
    expect(response.body).to include(classroom_path(assigned_classroom))
    expect(response.body).not_to include(classroom_path(unassigned_classroom))

    sign_in manager
    get school_path(school)
    expect(response.body).to include(classroom_path(assigned_classroom), classroom_path(unassigned_classroom))

    sign_in admin
    get school_path(school)
    expect(response.body).to include(classroom_path(assigned_classroom), classroom_path(unassigned_classroom))
  end

  it 'rejects an unassigned teacher and a student' do
    [create(:user, :teacher), create(:user, :student)].each do |user|
      sign_in user
      get school_path(school)
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'does not expose school workspace links from the classrooms index' do
    sign_in admin
    get classrooms_path
    expect(response.body).not_to include(school_path(school))

    sign_in member
    get classrooms_path
    expect(response.body).not_to include(school_path(school))
    expect(response.body).not_to include(school_path(other_school))
    expect(response.body).not_to include('translation missing')
  end

  it 'does not show a member school closure summary in the classrooms index' do
    closure = create(:school_closure, school: school, name: '재량휴업일', starts_on: 1.day.from_now.to_date,
                                      ends_on: 1.day.from_now.to_date)
    sign_in member

    get classrooms_path

    expect(response.body).not_to include(school_path(school))
    expect(response.body).not_to include(closure.name)
  end

  def calendar_day(document, date)
    label = I18n.l(date, format: :long)
    document.at_css(%([aria-label^="#{label}"]))
  end
end
