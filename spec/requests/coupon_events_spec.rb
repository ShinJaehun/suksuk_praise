require 'rails_helper'

RSpec.describe 'Coupon events', type: :request do
  include ActionView::RecordIdentifier

  let(:classroom) { create(:classroom, name: '햇살반') }
  let(:teacher) { create(:user, :teacher, name: '신재훈') }

  before do
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
  end

  def document
    Nokogiri::HTML(response.body)
  end

  def selected_value(selector)
    document.at_css(selector).at_css('option[selected]')['value']
  end

  it 'shows a reset link that returns to the default coupon event filters' do
    sign_in teacher

    get coupon_events_path(classroom_id: classroom.id, event_action: 'issued', period: 'all_time',
                           sort: 'issued_at_asc')

    expect(response).to have_http_status(:ok)

    reset_link = document.at_css(
      "form[action='#{coupon_events_path}'] a[href='#{coupon_events_path}']"
    )

    expect(reset_link.text).to include('필터 초기화')
    expect(response.body).to include('최근 7일')
    expect(selected_value("select[name='period']")).to eq('all_time')

    get coupon_events_path

    expect(selected_value("select[name='period']")).to eq('last_7_days')
  end

  it 'keeps pagination styling generic for event logs' do
    create_list(:coupon_event, 11, actor: teacher, classroom: classroom)
    sign_in teacher

    get coupon_events_path(period: 'all_time')

    expect(response.body).to include('event-log-pagination')
    expect(response.body).not_to include('coupon-events-pagy')
  end

  it "keeps an empty note action inline without rendering an empty panel" do
    event = create(:coupon_event, actor: teacher, classroom: classroom)
    sign_in teacher

    get coupon_events_path(period: "all_time")

    item = document.at_css(%([data-activity-source="CouponEvent"][data-activity-source-id="#{event.id}"]))
    line = item.at_css("[data-activity-log-line]")
    frame = line.at_css(%(turbo-frame[id="#{dom_id(event, :activity_notes)}"]))
    expect(frame["class"]).to include("contents")
    expect(frame.at_css('[data-activity-note-action="new"]')).to be_present
    expect(frame.at_css("[data-student-activity-note-panel]")).to be_nil
  end

  it "keeps an inactive teacher visible as a past event actor" do
    event = create(:coupon_event, actor: teacher, classroom: classroom)
    teacher.update!(active: false)
    sign_in create(:user, :admin)

    get coupon_events_path(period: "all_time")

    item = document.at_css(%([data-activity-source="CouponEvent"][data-activity-source-id="#{event.id}"]))
    expect(item).to be_present
    expect(item.text).to include(teacher.name)
  end

  it 'shows source-scoped note controls and existing notes' do
    other_teacher = create(:user, :teacher, name: "다른 교사")
    create(:classroom_membership, classroom: classroom, user: other_teacher, role: "teacher")
    event = create(:coupon_event, actor: teacher, classroom: classroom)
    own_note = create(:student_activity_note, source: event, author: teacher, body: "내 메모")
    create(:student_activity_note, source: event, author: other_teacher, body: "다른 메모")
    sign_in teacher

    get coupon_events_path(period: "all_time")

    panel = document.at_css(%([data-activity-source="CouponEvent"][data-activity-source-id="#{event.id}"]))
    frame_id = dom_id(event, :activity_notes)
    expect(panel.at_css(%(turbo-frame[id="#{frame_id}"]))).to be_present
    notes_panel = panel.at_css("[data-student-activity-note-panel]")
    expect(notes_panel["class"]).to include("basis-full", "w-full")
    expect(panel.text).to include("내 메모", "다른 메모", teacher.name, other_teacher.name)
    expect(panel.at_css(%(a[href^="#{edit_student_activity_note_path(own_note)}"][data-activity-note-action="edit"]))).to be_present
    expect(panel.css('[data-activity-note-action="edit"]').size).to eq(1)
    expect(panel.at_css('[data-activity-note-action="new"]')).to be_nil
  end
end
