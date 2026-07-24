require 'rails_helper'

RSpec.describe 'Coupon events', type: :request do
  let(:classroom) { create(:classroom, name: '햇살반') }
  let(:teacher) { create(:user, :teacher, name: '신재훈') }

  before do
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
  end

  def document
    Nokogiri::HTML(response.body)
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
  end

  it 'keeps pagination styling generic for event logs' do
    create_list(:coupon_event, 11, actor: teacher, classroom: classroom)
    sign_in teacher

    get coupon_events_path(period: 'all_time')

    expect(response.body).to include('event-log-pagination')
    expect(response.body).not_to include('coupon-events-pagy')
  end
end
