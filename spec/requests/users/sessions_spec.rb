require 'rails_helper'

RSpec.describe 'Users::Sessions', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:teacher) { create(:user, :teacher, password: 'password123') }
  let(:admin) { create(:user, :admin, password: 'password123') }
  let(:student) { create(:user, :student, student_pin: '1234') }
  let(:classroom) { create(:classroom) }

  before do
    create(:classroom_membership, classroom: classroom, user: student, role: 'student')
  end

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_cache
  end

  def post_password_login(email:, password:, ip: '203.0.113.10')
    post user_session_path,
         params: { user: { email: email, password: password } },
         headers: { 'REMOTE_ADDR' => ip }
  end

  it 'does not show a public sign up link on the login page' do
    get new_user_session_path

    expect(response.body).not_to include('Sign up')
    expect(response.body).not_to include(new_user_registration_path)
    expect(response.body).to include('Forgot your password?')
    expect(response.body).to include(new_user_password_path)
  end

  it 'signs a teacher in and redirects directly to classrooms index' do
    post user_session_path, params: {
      user: {
        email: teacher.email,
        password: 'password123'
      }
    }

    expect(response).to redirect_to(classrooms_path)
    expect(controller.current_user).to eq(teacher)
  end

  it 'rejects an inactive teacher with valid credentials' do
    teacher.update!(active: false)

    post user_session_path, params: {
      user: {
        email: teacher.email,
        password: 'password123'
      }
    }

    expect(response).to redirect_to(new_user_session_path)

    follow_redirect!

    expect(response.body).to include(I18n.t('devise.failure.inactive'))

    get classrooms_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'signs out a teacher on the next request after deactivation' do
    sign_in teacher
    teacher.update!(active: false)

    get classrooms_path

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq(I18n.t('devise.failure.inactive'))

    follow_redirect!

    expect(response.body).to include(I18n.t('devise.failure.inactive'))

    get classrooms_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'keeps the teacher Devise sign out path available' do
    sign_in teacher

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Sign out')
    expect(response.body).to include(destroy_user_session_path)
    expect(response.body).not_to include(destroy_student_session_path)
  end

  it 'signs an admin in and redirects directly to schools index' do
    post user_session_path, params: {
      user: {
        email: admin.email,
        password: 'password123'
      }
    }

    expect(response).to redirect_to(schools_path)
    expect(controller.current_user).to eq(admin)
  end

  it 'keeps the existing Devise failure response for the first four failures' do
    4.times do
      post_password_login(email: teacher.email, password: 'wrong-password')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('devise.failure.invalid', authentication_keys: 'email'))
    end
  end

  it 'blocks on the fifth failure and does not authenticate while blocked' do
    4.times { post_password_login(email: teacher.email, password: 'wrong-password') }

    post_password_login(email: teacher.email, password: 'wrong-password')

    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include(I18n.t('users.sessions.throttled'))
    expect(response.body).not_to include('wrong-password')
    expect(controller.current_user).to be_nil

    post_password_login(email: teacher.email, password: 'password123')

    expect(response).to have_http_status(:too_many_requests)
    expect(controller.current_user).to be_nil
  end

  it 'allows login after the ten-minute block expires' do
    travel_to Time.zone.local(2026, 8, 18, 10, 0, 0) do
      5.times { post_password_login(email: teacher.email, password: 'wrong-password') }
    end

    travel_to Time.zone.local(2026, 8, 18, 10, 10, 1) do
      post_password_login(email: teacher.email, password: 'password123')
    end

    expect(response).to redirect_to(classrooms_path)
    expect(controller.current_user).to eq(teacher)
  end

  it 'resets failures after a successful login before throttling' do
    4.times { post_password_login(email: teacher.email, password: 'wrong-password') }
    post_password_login(email: teacher.email, password: 'password123')
    delete destroy_user_session_path

    4.times { post_password_login(email: teacher.email, password: 'wrong-password') }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response).not_to have_http_status(:too_many_requests)
  end

  it 'keeps attempts for different IPs and emails separate' do
    5.times { post_password_login(email: teacher.email, password: 'wrong-password') }

    post_password_login(email: teacher.email, password: 'password123', ip: '203.0.113.11')
    expect(response).to redirect_to(classrooms_path)
    delete destroy_user_session_path

    post_password_login(email: admin.email, password: 'password123')
    expect(response).to redirect_to(schools_path)
  end

  it 'applies the same limit to an email that does not exist' do
    4.times { post_password_login(email: 'missing@example.com', password: 'wrong-password') }

    post_password_login(email: 'missing@example.com', password: 'wrong-password')

    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include(I18n.t('users.sessions.throttled'))
    expect(controller.current_user).to be_nil
  end

  it 'blocks a student from signing in with Devise' do
    post user_session_path, params: {
      user: {
        email: 'student@example.com',
        password: 'password123'
      }
    }

    expect(controller.current_user).to be_nil
  end

  it 'still allows a student to sign in with the classroom PIN flow' do
    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '1234'
    }

    expect(response).to redirect_to(classroom_student_path(classroom, student))
  end

  it "blocks an inactive school's PIN page and restores it after reactivation" do
    classroom.school.update!(active: false)

    get public_student_login_path(student_login_token: classroom.student_login_token)
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(student.name)

    classroom.school.update!(active: true)
    get public_student_login_path(student_login_token: classroom.student_login_token)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(student.name)
  end

  it 'expires an existing student session when the school becomes inactive' do
    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '1234'
    }
    classroom.school.update!(active: false)

    get classroom_student_path(classroom, student)

    expect(response).to redirect_to(
      public_student_login_path(student_login_token: classroom.student_login_token)
    )
    expect(controller.current_user).to be_nil
  end
end
