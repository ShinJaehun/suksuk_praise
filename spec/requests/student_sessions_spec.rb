require 'rails_helper'

RSpec.describe 'Student PIN sessions', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:classroom) { create(:classroom) }
  let(:student) { create(:user, :student, student_pin: '1234') }
  let(:teacher) { create(:user, :teacher) }
  let(:remote_ip) { '203.0.113.10' }

  before do
    create(:classroom_membership, classroom: classroom, user: student, role: 'student')
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
  end

  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original_cache
  end

  def post_student_pin(pin:, target_student: student, target_classroom: classroom, ip: remote_ip)
    post public_student_login_path(student_login_token: target_classroom.student_login_token),
      params: {
        student_id: target_student.id,
        student_pin: pin
      },
      headers: { 'REMOTE_ADDR' => ip }
  end

  def capture_request_log
    io = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(io))
    yield
    io.string
  ensure
    Rails.logger = original_logger
  end

  it 'does not expose all classrooms and students on the global login page' do
    other_classroom = create(:classroom, name: '다른 교실')
    other_student = create(:user, :student, name: '다른 학생', student_pin: '5678')
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: 'student')

    get new_student_session_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('교실별 로그인 주소')
    expect(response.body).not_to include(classroom.name)
    expect(response.body).not_to include(student.name)
    expect(response.body).not_to include(other_classroom.name)
    expect(response.body).not_to include(other_student.name)
  end

  it 'shows only students from the classroom login page' do
    other_classroom = create(:classroom)
    other_student = create(:user, :student, name: '다른 학생', student_pin: '5678')
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: 'student')

    get public_student_login_path(student_login_token: classroom.student_login_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(student.name)
    expect(response.body).to include('data-controller="student-login-preview"')
    expect(response.body).to include('data-student-login-preview-target="select"')
    expect(response.body).to include('로그인할 학생을 선택하세요')
    expect(response.body).to include('<option value="">선택하세요</option>')
    expect(response.body).to include('PIN을 입력하세요')
    expect(response.body).to include('suksuk_logo')
    expect(response.body).not_to include('alt="선택하세요"')
    expect(response.body).to include('data-avatar-url=')
    expect(response.body).to include("data-student-name=\"#{student.name}\"")
    expect(response.body).not_to include('선택한 학생의 아바타가 여기에 표시됩니다.')
    expect(response.body).not_to include(other_student.name)
  end

  it 'does not show inactive students on the classroom login page' do
    inactive_student = create(:user, :student, name: '비활성 학생', student_pin: '5678')
    create(:classroom_membership, classroom: classroom, user: inactive_student, role: 'student', status: 'inactive')

    get public_student_login_path(student_login_token: classroom.student_login_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(student.name)
    expect(response.body).not_to include(inactive_student.name)
  end

  it 'shows only students from the token classroom login page' do
    other_classroom = create(:classroom)
    other_student = create(:user, :student, name: '다른 학생', student_pin: '5678')
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: 'student')

    get public_student_login_path(student_login_token: classroom.student_login_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(student.name)
    expect(response.body).to include(public_student_login_path(student_login_token: classroom.student_login_token))
    expect(response.body).to include('data-controller="student-login-preview"')
    expect(response.body).to include('data-student-login-preview-target="select"')
    expect(response.body).to include('로그인할 학생을 선택하세요')
    expect(response.body).to include('<option value="">선택하세요</option>')
    expect(response.body).to include('PIN을 입력하세요')
    expect(response.body).to include('suksuk_logo')
    expect(response.body).not_to include('alt="선택하세요"')
    expect(response.body).to include('data-avatar-url=')
    expect(response.body).to include("data-student-name=\"#{student.name}\"")
    expect(response.body).not_to include('선택한 학생의 아바타가 여기에 표시됩니다.')
    expect(response.body).not_to include(other_student.name)
  end

  it 'returns not found for an invalid student login token' do
    get public_student_login_path(student_login_token: 'invalid-token')

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('학생 로그인 주소를 사용할 수 없습니다.')
    expect(response.body).to include('새 QR 코드나 로그인 주소')
  end

  it 'filters the raw token from valid GET student login request logs' do
    token = classroom.student_login_token

    logs = capture_request_log do
      get public_student_login_path(student_login_token: token)
    end

    expect(response).to have_http_status(:ok)
    expect(logs).to include('/c/[FILTERED]/login')
    expect(logs).not_to include(token)
  end

  it 'filters the raw token and PIN from POST student login request logs' do
    token = classroom.student_login_token

    logs = capture_request_log do
      post public_student_login_path(student_login_token: token), params: {
        student_id: student.id,
        student_pin: '1234'
      }
    end

    expect(response).to redirect_to(classroom_student_path(classroom, student))
    expect(logs).to include('/c/[FILTERED]/login')
    expect(logs).not_to include(token)
    expect(logs).not_to include('1234')
    expect(logs).to include('[FILTERED]')
  end

  it 'filters an invalid raw token from request logs' do
    invalid_token = 'invalid-student-login-token'

    logs = capture_request_log do
      get public_student_login_path(student_login_token: invalid_token)
    end

    expect(response).to have_http_status(:not_found)
    expect(logs).to include('/c/[FILTERED]/login')
    expect(logs).not_to include(invalid_token)
  end

  it 'does not mask ordinary request paths' do
    logs = capture_request_log do
      get new_student_session_path
    end

    expect(response).to have_http_status(:ok)
    expect(logs).to include('/student_login')
    expect(logs).not_to include('/c/[FILTERED]/login')
  end

  it 'does not route a numeric classroom login URL' do
    expect do
      Rails.application.routes.recognize_path(
        "/classrooms/#{classroom.id}/student_login",
        method: :get
      )
    end.to raise_error(ActionController::RoutingError)
  end

  it 'does not route a numeric login URL for another classroom' do
    other_classroom = create(:classroom)

    expect do
      Rails.application.routes.recognize_path(
        "/classrooms/#{other_classroom.id}/student_login",
        method: :post
      )
    end.to raise_error(ActionController::RoutingError)
  end

  it 'does not treat a numeric classroom id as a student login token' do
    get public_student_login_path(student_login_token: classroom.id)

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('학생 로그인 주소를 사용할 수 없습니다.')
    expect(response.body).not_to include(student.name)
  end

  it 'signs in a student with classroom, student, and PIN' do
    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '1234'
    }

    expect(response).to redirect_to(classroom_student_path(classroom, student))
  end

  it 'signs in a student through the token classroom login route' do
    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '1234'
    }

    expect(response).to redirect_to(classroom_student_path(classroom, student))
    expect(session[:student_login_classroom_id]).to eq(classroom.id)
  end

  it 'stores the student session last seen timestamp after PIN login' do
    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '1234'
    }

    expect(session[:student_login_classroom_id]).to eq(classroom.id)
    expect(session[:student_last_seen_at]).to be_present
  end

  it 'keeps a student signed in within the TTL and refreshes last seen' do
    travel_to Time.zone.local(2026, 5, 22, 10, 0, 0) do
      post public_student_login_path(student_login_token: classroom.student_login_token), params: {
        student_id: student.id,
        student_pin: '1234'
      }
    end

    travel_to Time.zone.local(2026, 5, 22, 10, 5, 0) do
      get classroom_student_path(classroom, student)
    end

    expect(response).to have_http_status(:ok)
    expect(session[:student_last_seen_at]).to eq(Time.zone.local(2026, 5, 22, 10, 5, 0).to_i)
  end

  it 'redirects an expired student session to the classroom PIN login page' do
    travel_to Time.zone.local(2026, 5, 22, 10, 0, 0) do
      post public_student_login_path(student_login_token: classroom.student_login_token), params: {
        student_id: student.id,
        student_pin: '1234'
      }
    end

    travel_to Time.zone.local(2026, 5, 22, 10, 21, 1) do
      get classroom_student_path(classroom, student)
    end

    expect(response).to redirect_to(public_student_login_path(student_login_token: classroom.student_login_token))
    expect(controller.current_user).to be_nil
  end

  it 'falls back to the global student login page when an expired session has no classroom' do
    sign_in student

    travel_to Time.zone.local(2026, 5, 22, 10, 0, 0) do
      get classroom_student_path(classroom, student)
    end

    travel_to Time.zone.local(2026, 5, 22, 10, 21, 1) do
      get user_path(student)
    end

    expect(response).to redirect_to(new_student_session_path)
    expect(controller.current_user).to be_nil
  end

  it 'initializes missing student last seen without expiring the session' do
    sign_in student

    get user_path(student)

    expect(response).to redirect_to(classroom_student_path(classroom, student))
    expect(session[:student_last_seen_at]).to be_present
  end

  it 'redirects student logout back to the classroom PIN login page' do
    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '1234'
    }

    expect(session[:student_login_classroom_id]).to eq(classroom.id)

    delete destroy_student_session_path

    expect(response).to redirect_to(public_student_login_path(student_login_token: classroom.student_login_token))
  end

  it 'falls back to the global student login page without a stored classroom' do
    sign_in student

    delete destroy_student_session_path

    expect(response).to redirect_to(new_student_session_path)
  end

  it 'shows a student-specific logout link on the self page' do
    sign_in student

    get classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('사용 끝내기')
    expect(response.body).to include(destroy_student_session_path)
    expect(response.body).not_to include(destroy_user_session_path)
  end

  it 'does not apply student TTL to a teacher' do
    sign_in teacher

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(controller.current_user).to eq(teacher)
  end

  it 'rejects an invalid PIN' do
    post_student_pin(pin: '0000')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('학생 PIN 로그인')
  end

  it 'keeps the existing failure response for the first four failed PIN attempts' do
    4.times do
      post_student_pin(pin: '0000')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('교실, 학생, PIN을 확인해 주세요.')
      expect(response.body).not_to include('로그인 시도가 너무 많습니다.')
    end
  end

  it 'blocks the same student, classroom, and IP after five failed PIN attempts' do
    4.times { post_student_pin(pin: '0000') }

    post_student_pin(pin: '0000')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.')
    expect(response.body).to include(student.name)

    post_student_pin(pin: '1234')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.')
    expect(response.body).to include(student.name)
    expect(controller.current_user).to be_nil
  end

  it 'allows login again after the throttle window expires' do
    travel_to Time.zone.local(2026, 5, 22, 10, 0, 0) do
      5.times { post_student_pin(pin: '0000') }
    end

    travel_to Time.zone.local(2026, 5, 22, 10, 10, 1) do
      post_student_pin(pin: '1234')
    end

    expect(response).to redirect_to(classroom_student_path(classroom, student))
  end

  it 'resets failed attempts after a successful PIN login before throttling' do
    4.times { post_student_pin(pin: '0000') }
    post_student_pin(pin: '1234')
    delete destroy_student_session_path

    4.times { post_student_pin(pin: '0000') }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('교실, 학생, PIN을 확인해 주세요.')
    expect(response.body).not_to include('로그인 시도가 너무 많습니다.')
  end

  it 'does not throttle a different student on the same IP' do
    other_student = create(:user, :student, student_pin: '5678')
    create(:classroom_membership, classroom: classroom, user: other_student, role: 'student')
    5.times { post_student_pin(pin: '0000') }

    post_student_pin(pin: '5678', target_student: other_student)

    expect(response).to redirect_to(classroom_student_path(classroom, other_student))
  end

  it 'does not throttle a different classroom on the same IP' do
    other_classroom = create(:classroom)
    other_student = create(:user, :student, student_pin: '5678')
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: 'student')
    5.times { post_student_pin(pin: '0000') }

    post_student_pin(pin: '5678', target_student: other_student, target_classroom: other_classroom)

    expect(response).to redirect_to(classroom_student_path(other_classroom, other_student))
  end

  it 'does not throttle the same student from a different IP' do
    5.times { post_student_pin(pin: '0000') }

    post_student_pin(pin: '1234', ip: '203.0.113.11')

    expect(response).to redirect_to(classroom_student_path(classroom, student))
  end

  it 'keeps invalid token handling outside PIN throttling' do
    get public_student_login_path(student_login_token: 'invalid-token')

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('학생 로그인 주소를 사용할 수 없습니다.')
  end

  it 'does not affect teacher Devise login' do
    5.times { post_student_pin(pin: '0000') }

    post user_session_path, params: {
      user: {
        email: teacher.email,
        password: 'password123'
      }
    }

    expect(response).to redirect_to(classrooms_path)
    expect(controller.current_user).to eq(teacher)
  end

  it 'rejects an inactive student with a valid PIN' do
    classroom.classroom_memberships.find_by!(user: student).inactive!

    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '1234'
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('교실, 학생, PIN을 확인해 주세요.')
    expect(controller.current_user).to be_nil
  end

  it 'signs out a student whose membership becomes inactive after PIN login' do
    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '1234'
    }
    classroom.classroom_memberships.find_by!(user: student).inactive!

    get classroom_student_path(classroom, student)

    expect(response).to redirect_to(public_student_login_path(student_login_token: classroom.student_login_token))
    expect(controller.current_user).to be_nil
  end

  it 'rejects a student outside the classroom' do
    other_classroom = create(:classroom)
    other_student = create(:user, :student, student_pin: '5678')
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: 'student')

    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: other_student.id,
      student_pin: '5678'
    }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'renders the managed student PIN field as an empty password input with the default PIN status' do
    sign_in teacher

    get edit_classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('type="password"')
    expect(response.body).to include('name="user[student_pin]"')
    expect(response.body).to include('현재 PIN:')
    expect(response.body).to include('기본 PIN(1234)으로 설정됨')
    expect(response.body).to include('새 PIN을 입력하면 변경됩니다. 비워두면 기존 PIN을 유지합니다.')
    expect(response.body).not_to include(student.student_pin_digest)
  end

  it 'shows the custom PIN status after the managed PIN changes from 1234' do
    student.update!(student_pin: '4321')
    sign_in teacher

    get edit_classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('현재 PIN:')
    expect(response.body).to include('설정됨')
    expect(response.body).not_to include('기본 PIN(1234)으로 설정됨')
  end

  it 'shows the unset PIN status for a student without a PIN' do
    student.update_column(:student_pin_digest, nil)
    sign_in teacher

    get edit_classroom_student_path(classroom, student)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('현재 PIN:')
    expect(response.body).to include('미설정')
  end

  it 'lets a teacher update the student PIN and then sign in with it' do
    sign_in teacher

    patch classroom_student_path(classroom, student), params: {
      user: {
        name: student.name,
        student_pin: '4321'
      }
    }

    expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
    expect(User.find(student.id).authenticate_student_pin('4321')).to be_truthy

    delete destroy_user_session_path

    post public_student_login_path(student_login_token: classroom.student_login_token), params: {
      student_id: student.id,
      student_pin: '4321'
    }

    expect(response).to redirect_to(classroom_student_path(classroom, student))
  end

  it 'keeps the existing student PIN when the managed PIN field is blank' do
    original_digest = student.student_pin_digest
    sign_in teacher

    patch classroom_student_path(classroom, student), params: {
      user: {
        name: '새 이름',
        student_pin: ''
      }
    }

    expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
    expect(student.reload.student_pin_digest).to eq(original_digest)
    expect(student.authenticate_student_pin('1234')).to be_truthy
  end

  it 'rejects an invalid managed student PIN format' do
    original_digest = student.student_pin_digest
    sign_in teacher

    patch classroom_student_path(classroom, student), params: {
      user: {
        name: student.name,
        student_pin: '12ab'
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(student.reload.student_pin_digest).to eq(original_digest)
  end
end
