require 'rails_helper'

RSpec.describe 'Admin teachers', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: '담당 교사') }

  it 'shows the teacher management index to an admin' do
    school = create(:school, name: '새싹초등학교', color_key: 'orange')
    other_school = create(:school, name: '나래초등학교')
    classroom = create(:classroom, school: school, grade: 4, name: '4학년 1반')
    later_classroom = create(:classroom, school: school, grade: 6, name: '기러기반')
    manager = create(:school_membership, :manager, school: school, user: teacher).user
    member_teacher = create(:school_membership, school: school, user: create(:user, :teacher, name: '일반 선생님')).user
    unassigned_teacher = create(:user, :teacher, name: '미배정 선생님')
    create(:classroom_membership, classroom: later_classroom, user: manager, role: :teacher)
    create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
    sign_in admin

    get admin_teachers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('선생님 관리')
    expect(response.body).to include('선생님 추가')
    expect(response.body).to include('id="teacher-school-filter"')
    expect(response.body).to include('name="school_id"')
    expect(response.body).to include('전체 학교')
    expect(response.body).to include(school.name, other_school.name)
    expect(response.body).to include('담당 교사', '새싹초등학교', '대표 선생님', '4학년 1반', '6학년 기러기반')
    expect(response.body).to include('일반 선생님', '선생님')
    expect(response.body).to include('미배정 선생님', '학교 미지정', '해당 없음', '담당 교실 없음')
    expect(response.body).not_to include('학교 역할', '학교 관리자', '일반 구성원', '담당 교실 2개')
    expect(response.body).to include(new_admin_teacher_path)
    expect(response.body).to include(edit_admin_teacher_path(manager))
    expect(response.body).to include(edit_admin_teacher_path(member_teacher))
    expect(response.body).not_to include('data-turbo-frame="modal"')

    document = Nokogiri::HTML(response.body)
    teacher_row = document.at_xpath("//p[normalize-space()='#{teacher.name}']/ancestor::article[1]")
    member_row = document.at_xpath("//p[normalize-space()='#{member_teacher.name}']/ancestor::article[1]")
    unassigned_row = document.at_xpath("//p[normalize-space()='#{unassigned_teacher.name}']/ancestor::article[1]")

    expect(teacher_row['class']).to include('border-l-orange-400', 'bg-orange-50/60')
    expect(teacher_row.at_css('.bg-orange-500')).to be_present
    expect(teacher_row.at_css('.bg-violet-100')&.text).to include('대표 선생님')
    expect(member_row.at_css('.bg-sky-100')&.text).to include('선생님')
    expect(teacher_row.text.index('4학년 1반')).to be < teacher_row.text.index('6학년 기러기반')
    expect(unassigned_row['class']).to include('border-l-slate-200', 'bg-white')
    expect(unassigned_row.css('.bg-slate-100').map(&:text)).to include('학교 미지정', '해당 없음', '담당 교실 없음')
    expect(unassigned_row.css("[class*='bg-orange-500']").to_a).to be_empty
  end

  it 'filters the teacher management index by school' do
    school = create(:school, name: '새싹초등학교')
    other_school = create(:school, name: '나래초등학교')
    school_teacher = create(:school_membership, school: school, user: create(:user, :teacher, name: '새싹 선생님')).user
    other_school_teacher = create(:school_membership, school: other_school,
                                                      user: create(:user, :teacher, name: '나래 선생님')).user
    unassigned_teacher = create(:user, :teacher, name: '미배정 선생님')
    sign_in admin

    get admin_teachers_path, params: { school_id: school.id }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="teacher-school-filter"')
    expect(response.body).to match(%r{<option selected="selected" value="#{school.id}">#{school.name}</option>})
    expect(response.body).to include(school_teacher.name, school_teacher.email, edit_admin_teacher_path(school_teacher))
    expect(response.body).not_to include(other_school_teacher.name)
    expect(response.body).not_to include(edit_admin_teacher_path(other_school_teacher))
    expect(response.body).not_to include(unassigned_teacher.name)
  end

  it 'filters teachers by status and falls back invalid status to active' do
    active_teacher = create(
      :user,
      :teacher,
      name: '운영중 필터 교사'
    )

    inactive_teacher = create(
      :user,
      :teacher,
      name: '사용중지 필터 교사',
      active: false
    )

    sign_in admin

    get admin_teachers_path
    expect(response.body).to include(active_teacher.name)
    expect(response.body).not_to include(inactive_teacher.name)
    expect(Nokogiri::HTML(response.body).at_css('select[name="status"] option[selected]')['value']).to eq('active')

    get admin_teachers_path(status: 'inactive')
    expect(response.body).to include(inactive_teacher.name)
    expect(response.body).not_to include(active_teacher.name)

    get admin_teachers_path(status: 'all')
    expect(response.body).to include(active_teacher.name, inactive_teacher.name)

    get admin_teachers_path(status: 'unknown')
    document = Nokogiri::HTML(response.body)
    expect(response.body).to include(active_teacher.name)
    expect(response.body).not_to include(inactive_teacher.name)
    expect(document.at_css('select[name="status"] option[selected]')['value']).to eq('active')
    expect(document.at_css('option[value="unknown"][selected]')).to be_nil
  end

  it 'combines school and inactive status filters' do
    school = create(:school)
    other_school = create(:school)
    school_active = create(:school_membership, school: school, user: create(:user, :teacher, name: 'A 활성')).user
    school_inactive = create(:school_membership, school: school,
                                                 user: create(:user, :teacher, name: 'A 비활성', active: false)).user
    other_active = create(:school_membership, school: other_school, user: create(:user, :teacher, name: 'B 활성')).user
    other_inactive = create(:school_membership, school: other_school,
                                                user: create(:user, :teacher, name: 'B 비활성', active: false)).user
    sign_in admin

    get admin_teachers_path(school_id: school.id, status: 'inactive')

    document = Nokogiri::HTML(response.body)
    expect(response.body).to include(school_inactive.name)
    expect(response.body).not_to include(school_active.name, other_active.name, other_inactive.name)
    expect(document.at_css('select[name="school_id"] option[selected]')['value']).to eq(school.id.to_s)
    expect(document.at_css('select[name="status"] option[selected]')['value']).to eq('inactive')
  end

  it 'treats an invalid teacher school filter as the full teacher list' do
    school_teacher = create(:school_membership, school: create(:school),
                                                user: create(:user, :teacher, name: '소속 선생님')).user
    unassigned_teacher = create(:user, :teacher, name: '미배정 선생님')
    sign_in admin

    get admin_teachers_path, params: { school_id: 'missing' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(school_teacher.name, unassigned_teacher.name)
    expect(response.body).to include('학교 미지정')
    expect(response.body).not_to include('selected="selected" value="missing"')
  end

  it 'shows an empty state on the teacher management index' do
    sign_in admin

    get admin_teachers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('등록된 선생님이 없습니다.')
    expect(response.body).to include(new_admin_teacher_path)
    expect(response.body).not_to include('data-turbo-frame="modal"')
  end

  it 'renders the new teacher page' do
    sign_in admin

    get new_admin_teacher_path

    document = Nokogiri::HTML(response.body)
    avatar_key_input = document.at_css('input[name="user[avatar_key]"]')
    avatar_section = document.at_css('[data-teacher-avatar-preview-target="avatarSection"]')
    expect(response.body).to include('선생님 목록으로 돌아가기')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('선생님 추가')

    expect(response.body).to include('name="user[gender]"')
    expect(avatar_key_input['value']).to be_blank
    expect(avatar_section['hidden']).not_to be_nil
    expect(response.body).not_to include('type="radio"')
  end

  it 'renders school and classroom assignment fields on the new teacher page' do
    school = create(:school)
    classroom = create(:classroom, school: school)
    sign_in admin

    get new_admin_teacher_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<!DOCTYPE html>')
    expect(response.body).to include('선생님 추가')
    expect(response.body).to include('data-turbo-submits-with="저장 중..."')
    expect(response.body).not_to include('data-turbo-frame="_top"')
    expect(response.body).not_to include('data-turbo-frame="modal"')
    expect(response.body).not_to include('translation missing')
    expect(response.body).to include('name="user[gender]"')
    expect(response.body).to include('name="user[avatar_key]"')
    expect(response.body).to include('data-controller="teacher-school-classrooms"')
    expect(response.body).to include('name="school_id"', 'name="classroom_ids[]"')
    expect(response.body).to include(classroom.name)
  end

  it 'saves a submitted male teacher avatar_key for male gender' do
    sign_in admin

    post admin_teachers_path, params: {
      user: {
        name: '남자 교사',
        email: 'male-teacher@example.com',
        password: 'password123',
        gender: 'male',
        avatar_key: 'teacherM01'
      }
    }

    expect(User.teacher.find_by!(email: 'male-teacher@example.com').avatar_key).to eq('teacherM01')
  end

  it 'saves a submitted female teacher avatar_key for female gender' do
    sign_in admin

    post admin_teachers_path, params: {
      user: {
        name: '여자 교사',
        email: 'female-teacher@example.com',
        password: 'password123',
        gender: 'female',
        avatar_key: 'teacherF01'
      }
    }

    expect(User.teacher.find_by!(email: 'female-teacher@example.com').avatar_key).to eq('teacherF01')
  end

  it 'assigns any teacher avatar_key when gender is blank or invalid' do
    sign_in admin

    ['', 'unknown'].each_with_index do |gender, index|
      post admin_teachers_path, params: {
        user: {
          name: "기본 아바타 교사 #{index}",
          email: "default-avatar-teacher-#{index}@example.com",
          password: 'password123',
          gender: gender
        }
      }

      expect(User.teacher.find_by!(email: "default-avatar-teacher-#{index}@example.com").avatar_key).to be_in(User.avatar_keys_for_role('teacher'))
    end
  end

  it 'replaces an avatar_key that does not match gender' do
    sign_in admin

    post admin_teachers_path, params: {
      user: {
        name: '조작 방지 교사',
        email: 'ignored-avatar-teacher@example.com',
        password: 'password123',
        gender: 'male',
        avatar_key: 'teacherF01'
      }
    }

    expect(User.teacher.find_by!(email: 'ignored-avatar-teacher@example.com').avatar_key).to be_in(User::TEACHER_MALE_AVATAR_KEYS)
  end

  it 'keeps gender and the submitted avatar when teacher creation fails' do
    sign_in admin

    post admin_teachers_path, params: {
      user: {
        name: '',
        email: 'invalid-teacher@example.com',
        password: 'password123',
        gender: 'female',
        avatar_key: 'teacherF03'
      }
    }

    document = Nokogiri::HTML(response.body)
    avatar_section = document.at_css('[data-teacher-avatar-preview-target="avatarSection"]')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('<option selected="selected" value="female">여자</option>')
    expect(document.at_css('input[name="user[avatar_key]"]')['value']).to eq('teacherF03')
    expect(avatar_section['hidden']).to be_nil
    expect(response.body).to match(%r{src="[^"]*avatars/teacherF03[^"]*\.png"})
  end

  it 'links to the dedicated teacher management page from the index' do
    teacher
    sign_in admin

    get admin_teachers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_teacher_path(teacher))
    expect(response.body).not_to include('data-turbo-frame="modal"')
  end

  it 'renders the dedicated teacher management page' do
    sign_in admin

    get edit_admin_teacher_path(teacher)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('운영 설정')
    expect(response.body).to include("#{teacher.name} 선생님")
    expect(response.body).to include('기본 정보', '학교 소속 및 운영 권한')
    expect(response.body).to include('선생님 목록으로 돌아가기')
    expect(response.body).not_to include('data-turbo-frame="_top"')
  end

  it 'renders the full teacher management page even with a Turbo Frame header' do
    sign_in admin

    get edit_admin_teacher_path(teacher), headers: { 'Turbo-Frame' => 'modal' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<!DOCTYPE html>')
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to include('운영 설정')
    expect(response.body).to include('data-turbo-submits-with="저장 중..."')
    expect(response.body).to include('선생님 목록으로 돌아가기')
    expect(response.body).not_to include('data-turbo-frame="_top"')
    expect(response.body).not_to include('translation missing')
  end

  it 'blocks non-admin users from the teacher management index' do
    manager = create(:school_membership, :manager).user
    regular_teacher = create(:user, :teacher)
    student = create(:user, :student)

    [manager, regular_teacher, student].each do |user|
      sign_in user
      get admin_teachers_path
      expect(response).to redirect_to(root_path)
    end
  end

  it 'blocks non-admin users from teacher management actions' do
    manager = create(:school_membership, :manager).user
    regular_teacher = create(:user, :teacher)
    student = create(:user, :student)

    [manager, regular_teacher, student].each do |user|
      sign_in user

      get new_admin_teacher_path
      expect(response).to redirect_to(root_path)

      expect do
        post admin_teachers_path, params: {
          user: {
            name: '차단된 선생님',
            email: "blocked-#{user.id}@example.com",
            password: 'password123'
          }
        }
      end.not_to(change { User.teacher.count })
      expect(response).to redirect_to(root_path)

      get edit_admin_teacher_path(teacher)
      expect(response).to redirect_to(root_path)

      patch admin_teacher_path(teacher), params: { school_id: '' }
      expect(response).to redirect_to(root_path)

      patch deactivate_admin_teacher_path(teacher)
      expect(response).to redirect_to(root_path)

      teacher.update!(active: false)
      patch reactivate_admin_teacher_path(teacher)
      expect(response).to redirect_to(root_path)
      teacher.update!(active: true)
    end
  end

  it 'requires authentication for the teacher management index' do
    get admin_teachers_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'requires authentication for teacher status changes' do
    patch deactivate_admin_teacher_path(teacher)

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'does not define a teacher delete route' do
    expect do
      Rails.application.routes.recognize_path(
        "/admin/teachers/#{teacher.id}",
        method: :delete
      )
    end.to raise_error(ActionController::RoutingError)
  end

  it 'shows the teacher management navigation link only to admins' do
    manager_membership = create(:school_membership, :manager)
    regular_teacher = create(:user, :teacher)
    student = create(:user, :student)

    sign_in admin
    get schools_path
    expect(response.body).to include(admin_teachers_path)
    expect(response.body).to include(schools_path, classrooms_path)
    expect(response.body).not_to include(school_teachers_path(manager_membership.school))

    sign_in manager_membership.user
    assigned_classroom = create(:classroom, school: manager_membership.school)
    create(:classroom_membership, classroom: assigned_classroom, user: manager_membership.user, role: :teacher)
    get school_teachers_path(manager_membership.school)
    document = Nokogiri::HTML(response.body)
    expect(response.body).not_to include(admin_teachers_path)
    expect(response.body).to include(school_path(manager_membership.school))
    expect(response.body).to include(classrooms_path)
    expect(response.body).to include(school_teachers_path(manager_membership.school))
    expect(document.css(%(a[href="#{school_teachers_path(manager_membership.school)}"])).size).to eq(2)
    expect(response.body).not_to include(school_path(manager_membership.school, anchor: 'school-teachers'))

    sign_in regular_teacher
    get classrooms_path
    expect(response.body).not_to include(admin_teachers_path)
    expect(response.body).not_to include(school_teachers_path(manager_membership.school))
    expect(response.body).not_to include(school_path(manager_membership.school))

    sign_in student
    get user_path(student)
    expect(response.body).not_to include(admin_teachers_path)
  end

  it 'shows school classroom assignment inputs without a school teacher management link' do
    school = create(:school)
    other_school = create(:school)
    classroom = create(:classroom, school: school, name: '현재 학교 학급')
    other_classroom = create(:classroom, school: other_school, name: '다른 학교 학급')
    create(:school_membership, school: school, user: teacher)
    sign_in admin

    get edit_admin_teacher_path(teacher)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(name="classroom_ids[]"))
    expect(response.body).to include(classroom.name, other_classroom.name)
    expect(response.body).to include(%(value="#{other_classroom.id}"))
    expect(response.body).not_to include(school_teachers_path(school))
    expect(response.body).not_to include('담당 학급은 해당 학교의 선생님 관리 화면에서 배정합니다.')
  end

  it 'filters and changes teacher account status without removing assignments' do
    school = create(:school)
    classroom = create(:classroom, school: school)
    membership = create(:school_membership, school: school, user: teacher)
    classroom_membership = create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    sign_in admin

    patch deactivate_admin_teacher_path(teacher)
    expect(teacher.reload).to be_inactive
    expect(membership.reload).to be_present
    expect(classroom_membership.reload).to be_present

    get admin_teachers_path(status: 'inactive', school_id: school.id)
    expect(response.body).to include(teacher.name, '비활성')

    patch reactivate_admin_teacher_path(teacher)
    expect(teacher.reload).to be_active
  end

  it 'does not offer or accept a new assignment to an inactive school' do
    inactive_school = create(:school, name: '운영 중단 학교', active: false)
    sign_in admin

    get new_admin_teacher_path
    expect(response.body).not_to include(inactive_school.name)

    expect do
      post admin_teachers_path, params: {
        user: {
          name: '배정 금지 교사',
          email: 'inactive-school@example.com',
          password: 'password123'
        },
        school_id: inactive_school.id,
        classroom_ids: ['']
      }
    end.not_to change(User.teacher, :count)
  end

  it 'keeps an existing inactive-school assignment visible while allowing removal' do
    inactive_school = create(:school, active: false)
    membership = create(:school_membership, school: inactive_school, user: teacher)
    sign_in admin

    get edit_admin_teacher_path(teacher)
    expect(response.body).to include(inactive_school.name)

    patch admin_teacher_path(teacher), params: { school_id: '', classroom_ids: [''] }
    expect(response).to redirect_to(edit_admin_teacher_path(teacher))
    expect { membership.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(inactive_school.reload).to be_inactive
  end
end
