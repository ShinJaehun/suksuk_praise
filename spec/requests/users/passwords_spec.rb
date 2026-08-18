require 'rails_helper'

RSpec.describe 'Users::Passwords', type: :request do
  around do |example|
    original_default_url_options = ActionMailer::Base.default_url_options
    ActionMailer::Base.default_url_options = { host: 'example.com' }
    example.run
  ensure
    ActionMailer::Base.default_url_options = original_default_url_options
  end

  it 'returns the same user-facing response for registered and unregistered emails' do
    teacher = create(:user, :teacher)

    post user_password_path, params: { user: { email: teacher.email } }
    registered_response = {
      status: response.status,
      location: response.location,
      notice: flash[:notice]
    }

    post user_password_path, params: { user: { email: 'missing@example.com' } }
    unregistered_response = {
      status: response.status,
      location: response.location,
      notice: flash[:notice]
    }

    expect(unregistered_response).to eq(registered_response)
    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:notice]).to eq(I18n.t('devise.passwords.send_paranoid_instructions'))
  end
end
