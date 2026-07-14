require 'rails_helper'

RSpec.describe 'Admin public holiday sync', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:user, :teacher) }
  let(:teacher) { create(:user, :teacher) }
  let(:student) { create(:user, :student) }
  let(:school) { create(:school) }

  before do
    create(:school_membership, :manager, school: school, user: manager)
  end

  it 'shows sync buttons for the previous, current, and next years to global admins' do
    create(:public_holiday, date: Date.new(2024, 1, 1), source: PublicHolidays::SyncYear::SOURCE)
    create(:public_holiday, date: Date.new(2025, 1, 1), source: PublicHolidays::SyncYear::SOURCE)
    create(:public_holiday, date: Date.new(2026, 1, 1), source: 'manual')
    sign_in admin

    travel_to Time.zone.local(2026, 7, 14, 10, 0, 0) do
      get schools_path
    end

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)

    [2025, 2026, 2027].each do |year|
      form = sync_form_for(document, year)
      expect(form).to be_present
      expect(sync_button_for(document, year)&.text).to include("#{year}년 동기화")
      expect(sync_button_for(document, year)['data-turbo-submits-with']).to eq('동기화 중...')
    end

    expect(sync_button_for(document, 2025)['class']).to include('bg-sky-50')
    expect(sync_button_for(document, 2025)['aria-label']).to eq('2025년 공식 공휴일 동기화, 동기화된 데이터 있음')
    expect(sync_button_for(document, 2026)['class']).to include('bg-white')
    expect(sync_button_for(document, 2026)['class']).not_to include('bg-sky-50')
    expect(sync_button_for(document, 2026)['aria-label']).to eq('2026년 공식 공휴일 동기화, 동기화된 데이터 없음')
    expect(sync_button_for(document, 2027)['class']).to include('bg-white')
    expect(sync_button_for(document, 2027)['aria-label']).to eq('2027년 공식 공휴일 동기화, 동기화된 데이터 없음')
  end

  it 'does not expose the schools index sync card to non-admin users' do
    sign_in manager
    get schools_path
    expect(response).to redirect_to(school_path(school))

    sign_in teacher
    get schools_path
    expect(response).to redirect_to(root_path)

    sign_in student
    get schools_path
    expect(response).to redirect_to(root_path)
  end

  it 'syncs a requested year and redirects to the schools index' do
    sign_in admin
    allow(PublicHolidays::SyncYear).to receive(:call).and_return(1)

    post sync_admin_public_holidays_path(year: '2026')

    expect(PublicHolidays::SyncYear).to have_received(:call).with(year: 2026)
    expect(response).to redirect_to(schools_path)
    expect(flash[:notice]).to eq('2026년 공식 공휴일을 동기화했습니다.')
  end

  it 'handles expected sync failures and redirects to the schools index' do
    sign_in admin

    [
      PublicHolidays::SyncYear::EmptyResultError.new('empty'),
      PublicHolidays::KasiClient::ResponseError.new('response failed'),
      ActiveRecord::RecordInvalid.new(PublicHoliday.new)
    ].each do |error|
      allow(PublicHolidays::SyncYear).to receive(:call).and_raise(error)

      post sync_admin_public_holidays_path(year: '2026')

      expect(response).to redirect_to(schools_path)
      expect(flash[:alert]).to eq('공식 공휴일 동기화에 실패했습니다. 기존 데이터는 유지되었습니다.')
    end
  end

  it 'does not call the sync service for an invalid sync year' do
    sign_in admin
    allow(PublicHolidays::SyncYear).to receive(:call)

    post sync_admin_public_holidays_path(year: 'bad')

    expect(PublicHolidays::SyncYear).not_to have_received(:call)
    expect(response).to redirect_to(schools_path)
    expect(flash[:alert]).to eq('동기화할 연도를 확인해 주세요.')
  end

  it 'blocks non-admin and guest posts without calling the sync service' do
    allow(PublicHolidays::SyncYear).to receive(:call)

    post sync_admin_public_holidays_path(year: '2026')
    expect(response).to redirect_to(new_user_session_path)

    [manager, teacher, student].each do |user|
      sign_in user
      post sync_admin_public_holidays_path(year: '2026')
      expect(response).to redirect_to(root_path)
    end

    expect(PublicHolidays::SyncYear).not_to have_received(:call)
  end

  it 'does not provide a public holiday index route' do
    expect do
      Rails.application.routes.recognize_path('/admin/public_holidays', method: :get)
    end.to raise_error(ActionController::RoutingError)
  end

  def sync_form_for(document, year)
    document.css('form').find do |form|
      form['action'] == sync_admin_public_holidays_path(year: year) &&
        form['method'].to_s.casecmp('post').zero?
    end
  end

  def sync_button_for(document, year)
    sync_form_for(document, year)&.at_css('button')
  end
end
