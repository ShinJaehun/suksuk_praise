require 'rails_helper'

RSpec.describe 'Home', type: :request do
  let(:teacher) { create(:user, :teacher) }
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user, :student) }
  let(:classroom) { create(:classroom) }

  it 'redirects guests to the teacher and admin sign in page' do
    get root_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'redirects a signed-in teacher with no assigned classrooms to classrooms index' do
    sign_in teacher

    get root_path

    expect(response).to redirect_to(classrooms_path)
  end

  it 'redirects a signed-in teacher with one assigned classroom to that classroom' do
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    sign_in teacher

    get root_path

    expect(response).to redirect_to(classroom_path(classroom))
  end

  it 'redirects a signed-in teacher with multiple assigned classrooms to classrooms index' do
    other_classroom = create(:classroom)
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    create(:classroom_membership, classroom: other_classroom, user: teacher, role: 'teacher')
    sign_in teacher

    get root_path

    expect(response).to redirect_to(classrooms_path)
  end

  it 'redirects a signed-in admin to classrooms index' do
    sign_in admin

    get root_path

    expect(response).to redirect_to(classrooms_path)
  end

  it 'sends a signed-in student through the existing canonical student redirect flow' do
    create(:classroom_membership, classroom: classroom, user: student, role: 'student')
    sign_in student

    get root_path

    expect(response).to redirect_to(user_path(student))
  end

  it 'labels the Devise sign in page as teacher and admin login' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('교사/관리자 로그인')
  end
end
