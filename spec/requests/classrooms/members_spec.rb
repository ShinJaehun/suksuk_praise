require 'rails_helper'

RSpec.describe 'Classroom members', type: :request do
  let(:classroom) { create(:classroom, name: '2반') }
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: '담당 교사') }
  let(:other_teacher) { create(:user, :teacher, name: '추가 교사') }

  it 'shows member management sections to a classroom teacher' do
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    student = create(:user, :student, name: '활성 학생', gender: 'boy', avatar_key: 'boy01')
    create(:classroom_membership, classroom: classroom, user: student, role: 'student')
    sign_in teacher

    get classroom_members_path(classroom)

    document = Nokogiri::HTML(response.body)
    active_filter = document.at_css(
      %(a[href="#{classroom_members_path(classroom, status: 'active')}"])
    )
    inactive_filter = document.at_css(
      %(a[href="#{classroom_members_path(classroom, status: 'inactive')}"])
    )
    all_filter = document.at_css(
      %(a[href="#{classroom_members_path(classroom, status: 'all')}"])
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('구성원 관리')
    expect(response.body).to include('2반')
    expect(response.body).to include('학생 관리')
    expect(response.body).to include(student.name)
    expect(response.body).to include('alt="활성 학생 avatar"')

    expect(active_filter.text.squish).to eq('활성 1')
    expect(inactive_filter.text.squish).to eq('비활성 0')
    expect(all_filter.text.squish).to eq('전체 1')

    expect(response.body).to include('이름 일괄 수정')
    expect(response.body).to include(classroom_edit_member_student_names_path(classroom))
    expect(response.body).to include('id="student-creation-actions"')
    expect(response.body).to include('id="student-bulk-management-actions"')
    expect(response.body).to include('data-turbo-frame="modal"')
    expect(response.body).not_to include('id="student-name-editor"')
    expect(response.body).not_to include('id="student_names_form"')
    expect(response.body).not_to include('type="checkbox"')
    expect(response.body).to include(deactivate_classroom_student_path(classroom, student))
    expect(response.body).to include(new_classroom_student_path(classroom))
    expect(response.body).to include(new_classroom_student_path(classroom, return_to: 'members'))
    expect(response.body).to include(bulk_new_classroom_students_path(classroom))
    expect(response.body).to include(bulk_new_classroom_students_path(classroom, return_to: 'members'))
    expect(response.body).not_to include(%(action="#{classroom_member_student_names_path(classroom)}"))
    expect(response.body).to include(classroom_edit_member_student_pin_path(classroom))
    expect(response.body).to include('활성 학생 PIN 재설정')
    expect(response.body).not_to include(student_login_info_classroom_path(classroom))
    expect(response.body).not_to include('학생 로그인 관리')
    expect(response.body).to include(edit_classroom_student_path(classroom, student))
    expect(response.body).not_to include(coupon_assignment_classroom_student_path(classroom, student))
    expect(response.body).not_to include(public_student_login_url(student_login_token: classroom.student_login_token))
    expect(response.body).not_to include('QR 코드 보기')
    expect(response.body).not_to include('QR 코드 다운로드')
    expect(response.body).not_to include('학생 로그인 주소 재발급')
    expect(response.body).not_to include('담당 선생님 배정')
    expect(response.body).not_to include('classroom[teacher_ids][]')
  end

  it 'does not show teacher assignment controls to an admin' do
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    other_teacher
    sign_in admin

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('2반')
    expect(response.body).to include('학생 관리')
    expect(response.body).not_to include('담당 선생님 배정')
    expect(response.body).not_to include('담당 선생님 저장')
    expect(response.body).not_to include('classroom[teacher_ids][]')
    expect(response.body).not_to include('학생 로그인 주소 재발급')
  end

  it 'shows active students by default with matching row actions' do
    active_student = create(:user, :student, name: '김활동')
    inactive_student = create(:user, :student, name: '박휴식')
    active_membership = create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
    create(:classroom_membership, classroom: classroom, user: inactive_student, role: 'student', status: 'inactive')
    sign_in admin

    get classroom_members_path(classroom)

    document = Nokogiri::HTML(response.body)
    active_row = document.at_css("#member_row_classroom_membership_#{active_membership.id}")
    student_management = document.at_css('#student-management')

    expect(response).to have_http_status(:ok)
    expect(document.at_css(%(a[aria-current="page"])).text).to include('활성')
    expect(active_row.text).to include(active_student.name, '활성')
    expect(active_row.text).not_to include(active_membership.id.to_s)
    expect(response.body).to include(edit_classroom_student_path(classroom, active_student))
    expect(response.body).to include(deactivate_classroom_student_path(classroom, active_student))
    expect(response.body).to include('data-turbo-confirm')
    expect(response.body).to include('name="_method"')
    expect(response.body).to include('value="patch"')
    expect(response.body).not_to include(coupon_assignment_classroom_student_path(classroom, active_student))
    expect(response.body).not_to include(inactive_student.name)
    expect(response.body).not_to include(reactivate_classroom_student_path(classroom, inactive_student))
    expect(response.body).not_to include('더보기')

    expect(student_management.at_css('details')).to be_nil
    expect(student_management.at_css('input[type="checkbox"]')).to be_nil

    expect(response.body).to include('활성')
  end

  it 'filters inactive and all students with matching row actions' do
    active_student = create(:user, :student, name: '김활동')
    inactive_student = create(:user, :student, name: '박휴식')
    active_membership = create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
    inactive_membership = create(:classroom_membership, classroom: classroom, user: inactive_student, role: 'student',
                                                        status: 'inactive')
    sign_in admin

    get classroom_members_path(classroom, status: 'inactive')

    inactive_document = Nokogiri::HTML(response.body)
    inactive_row = inactive_document.at_css("#member_row_classroom_membership_#{inactive_membership.id}")

    expect(response).to have_http_status(:ok)
    expect(inactive_document.at_css(%(a[aria-current="page"])).text).to include('비활성')
    expect(response.body).not_to include(active_student.name)
    expect(inactive_row.text).to include(inactive_student.name, '비활성')
    expect(inactive_row.text).not_to include(inactive_membership.id.to_s)
    expect(response.body).not_to include("member_row_classroom_membership_#{active_membership.id}")
    expect(response.body).to include(edit_classroom_student_path(classroom, inactive_student))
    expect(response.body).to include(reactivate_classroom_student_path(classroom, inactive_student))
    expect(response.body).not_to include(deactivate_classroom_student_path(classroom, inactive_student))

    get classroom_members_path(classroom, status: 'all')

    all_document = Nokogiri::HTML(response.body)

    expect(all_document.at_css(%(a[aria-current="page"])).text).to include('전체')
    expect(response.body).to include(active_student.name, inactive_student.name)
    expect(all_document.at_css("#member_row_classroom_membership_#{active_membership.id}").text).not_to include(active_membership.id.to_s)
    expect(all_document.at_css("#member_row_classroom_membership_#{inactive_membership.id}").text).not_to include(inactive_membership.id.to_s)

    get classroom_members_path(classroom, status: 'unknown')

    fallback_document = Nokogiri::HTML(response.body)

    expect(fallback_document.at_css(%(a[aria-current="page"])).text).to include('활성')
    expect(response.body).to include(active_student.name)
    expect(response.body).not_to include(inactive_student.name)
  end

  it 'renders an empty inactive filter state' do
    active_student = create(:user, :student, name: '김활동')
    create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
    sign_in admin

    get classroom_members_path(classroom, status: 'inactive')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('비활성 학생이 없습니다.')
    expect(response.body).not_to include(active_student.name)
  end

  it 'does not count a legacy admin teacher membership as an assigned teacher' do
    create(:classroom_membership, classroom: classroom, user: admin, role: 'teacher')
    sign_in admin

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('담당 선생님 배정')
    expect(response.body).not_to include('0명 선택됨')
    expect(response.body).not_to include('checked="checked"')
  end

  it 'does not show a legacy admin teacher membership in the classrooms index preview' do
    create(:classroom_membership, classroom: classroom, user: admin, role: 'teacher')
    sign_in admin

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('담당 선생님 없음')
  end

  it 'rejects a teacher who does not manage the classroom' do
    sign_in teacher

    get classroom_members_path(classroom)

    expect(response).to redirect_to(root_path)
  end

  it 'rejects a manager who is not assigned to the classroom' do
    create(:school_membership, :manager, school: classroom.school, user: teacher)
    sign_in teacher

    get classroom_members_path(classroom)

    expect(response).to redirect_to(root_path)
  end

  it 'allows a manager assigned as the classroom teacher to manage members' do
    create(:school_membership, :manager, school: classroom.school, user: teacher)
    create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
    student = create(:user, :student, name: '활성 학생')
    create(:classroom_membership, classroom: classroom, user: student, role: :student)
    sign_in teacher

    get classroom_members_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('구성원 관리')
    expect(response.body).to include(student.name)
  end

  it 'renders the bulk student name edit modal for all student memberships' do
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    active_student = create(:user, :student, name: '활성 이름')
    inactive_student = create(:user, :student, name: '비활성 이름')
    active_membership = create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
    inactive_membership = create(:classroom_membership, classroom: classroom, user: inactive_student, role: 'student',
                                                        status: 'inactive')
    sign_in teacher

    get classroom_edit_member_student_names_path(classroom, status: 'inactive'), headers: { 'Turbo-Frame' => 'modal' }

    document = Nokogiri::HTML(response.body)
    form = document.at_css('form#student_names_form')
    active_row = document.at_css("#name_row_classroom_membership_#{active_membership.id}")
    inactive_row = document.at_css("#name_row_classroom_membership_#{inactive_membership.id}")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('이름 일괄 수정')
    expect(form['action']).to eq(classroom_member_student_names_path(classroom, status: 'inactive'))
    expect(active_row.text).not_to include(active_membership.id.to_s)
    expect(inactive_row.text).not_to include(inactive_membership.id.to_s)
    expect(response.body).to include(%(name="students[#{active_membership.id}][name]"))
    expect(response.body).to include(%(name="students[#{inactive_membership.id}][name]"))
    expect(response.body).to include('활성 이름', '비활성 이름')
  end

  it 'keeps the selected filter after saving names from the modal' do
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    active_student = create(:user, :student, name: '활성 저장 전')
    inactive_student = create(:user, :student, name: '비활성 저장 전')
    active_membership = create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
    inactive_membership = create(:classroom_membership, classroom: classroom, user: inactive_student, role: 'student',
                                                        status: 'inactive')
    sign_in teacher

    get classroom_members_path(classroom, status: 'inactive')
    inactive_document = Nokogiri::HTML(response.body)
    inactive_edit_link = inactive_document.at_css(%(a[href="#{classroom_edit_member_student_names_path(classroom,
                                                                                                       status: 'inactive')}"]))

    expect(inactive_edit_link['data-turbo-frame']).to eq('modal')

    patch classroom_member_student_names_path(classroom, status: 'inactive'),
          params: {
            students: {
              active_membership.id => { name: '활성 저장 후' },
              inactive_membership.id => { name: '비활성 저장 후' }
            }
          },
          headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

    inactive_result = Nokogiri::HTML.fragment(response.body)
    inactive_row = inactive_result.at_css(
      "#member_row_classroom_membership_#{inactive_membership.id}"
    )

    expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    expect(response.body).to include('target="student-management"', 'target="modal"')
    expect(inactive_result.at_css(%(a[aria-current="page"])).text).to include('비활성')

    expect(inactive_row.text).to include('비활성 저장 후')
    expect(inactive_result.at_css("#member_row_classroom_membership_#{active_membership.id}")).to be_nil
    expect(active_student.reload.name).to eq('활성 저장 후')

    get classroom_members_path(classroom, status: 'all')
    all_document = Nokogiri::HTML(response.body)
    all_edit_link = all_document.at_css(%(a[href="#{classroom_edit_member_student_names_path(classroom,
                                                                                             status: 'all')}"]))

    expect(all_edit_link['data-turbo-frame']).to eq('modal')

    patch classroom_member_student_names_path(classroom, status: 'all'),
          params: {
            students: {
              active_membership.id => { name: '활성 전체 저장' },
              inactive_membership.id => { name: '비활성 전체 저장' }
            }
          },
          headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

    all_result = Nokogiri::HTML.fragment(response.body)
    active_row = all_result.at_css(
      "#member_row_classroom_membership_#{active_membership.id}"
    )
    inactive_row = all_result.at_css(
      "#member_row_classroom_membership_#{inactive_membership.id}"
    )

    expect(all_result.at_css(%(a[aria-current="page"])).text).to include('전체')
    expect(active_row.text).to include('활성 전체 저장')
    expect(inactive_row.text).to include('비활성 전체 저장')
  end

  describe 'PATCH /classrooms/:classroom_id/members/students/name' do
    it 'lets a classroom teacher update active student names' do
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
      student = create(:user, :student, name: '이전 이름')
      membership = create(:classroom_membership, classroom: classroom, user: student, role: 'student')
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: '새 이름' }
        }
      }

      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(flash[:notice]).to eq(I18n.t('students.members.update_names.success'))
      expect(student.reload.name).to eq('새 이름')
    end

    it 'lets a classroom teacher update inactive student names' do
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
      student = create(:user, :student, name: '쉬는 학생')
      membership = create(:classroom_membership, classroom: classroom, user: student, role: 'student',
                                                 status: 'inactive')
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: '돌아올 학생' }
        }
      }

      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(student.reload.name).to eq('돌아올 학생')
    end

    it 'lets an admin update student names' do
      student = create(:user, :student, name: '관리 전')
      membership = create(:classroom_membership, classroom: classroom, user: student, role: 'student')
      sign_in admin

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: '관리 후' }
        }
      }

      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(student.reload.name).to eq('관리 후')
    end

    it 'rejects a teacher who does not manage the classroom' do
      student = create(:user, :student, name: '유지')
      membership = create(:classroom_membership, classroom: classroom, user: student, role: 'student')
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: '변경 시도' }
        }
      }

      expect(response).to redirect_to(root_path)
      expect(student.reload.name).to eq('유지')
    end

    it 'rejects a manager who is not assigned to the classroom' do
      create(:school_membership, :manager, school: classroom.school, user: teacher)
      student = create(:user, :student, name: '유지')
      membership = create(:classroom_membership, classroom: classroom, user: student, role: 'student')
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: '변경 시도' }
        }
      }

      expect(response).to redirect_to(root_path)
      expect(student.reload.name).to eq('유지')
    end

    it 'rejects a student' do
      student = create(:user, :student, name: '본인')
      membership = create(:classroom_membership, classroom: classroom, user: student, role: 'student')
      sign_in student

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: '변경 시도' }
        }
      }

      expect(response).to redirect_to(root_path)
      expect(student.reload.name).to eq('본인')
    end

    it 'fails when a membership outside the classroom is submitted' do
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
      student = create(:user, :student, name: '내 학생')
      membership = create(:classroom_membership, classroom: classroom, user: student, role: 'student')
      other_student = create(:user, :student, name: '다른 학생')
      other_membership = create(:classroom_membership, classroom: create(:classroom), user: other_student,
                                                       role: 'student')
      sign_in teacher

      patch classroom_member_student_names_path(classroom), params: {
        students: {
          membership.id => { name: '변경 실패' },
          other_membership.id => { name: '변경되면 안 됨' }
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t('students.members.update_names.invalid_membership'))
      expect(student.reload.name).to eq('내 학생')
      expect(other_student.reload.name).to eq('다른 학생')
    end

    it 'rolls back all changes and shows row errors when any name is invalid' do
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
      valid_student = create(:user, :student, name: '유효 학생')
      invalid_student = create(:user, :student, name: '무효 학생')
      valid_membership = create(:classroom_membership, classroom: classroom, user: valid_student, role: 'student')
      invalid_membership = create(:classroom_membership, classroom: classroom, user: invalid_student, role: 'student')
      sign_in teacher

      patch classroom_member_student_names_path(classroom, status: 'inactive'), params: {
        students: {
          valid_membership.id => { name: '저장되면 안 됨' },
          invalid_membership.id => { name: '' }
        }
      }

      document = Nokogiri::HTML(response.body)
      form = document.at_css('form#student_names_form')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('id="modal"')
      expect(form['action']).to eq(classroom_member_student_names_path(classroom, status: 'inactive'))
      expect(response.body).to include('이름을 확인해 주세요')
      expect(response.body).to include('저장되면 안 됨')
      expect(valid_student.reload.name).to eq('유효 학생')
      expect(invalid_student.reload.name).to eq('무효 학생')
    end
  end

  describe 'student PIN reset' do
    let(:turbo_headers) { { 'ACCEPT' => 'text/vnd.turbo-stream.html' } }

    it 'shows the PIN reset modal form' do
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
      sign_in teacher

      get classroom_edit_member_student_pin_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('활성 학생 PIN 재설정')
      expect(response.body).to include('새 PIN')
      expect(response.body).to include('PIN 재설정 적용')
      expect(response.body).to include(classroom_member_student_pin_path(classroom))
      expect(response.body).to include('name="student_pin"')
      expect(response.body).to include('type="password"')
      expect(response.body).to include('type="submit"')
      expect(response.body).to include('data-testid="active-student-pin-reset-submit"')
      expect(response.body).not_to include('1234')
    end

    it 'lets a classroom teacher reset active student PINs without changing inactive students' do
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
      active_student = create(:user, :student, student_pin: '1234')
      second_active_student = create(:user, :student, student_pin: '2345')
      inactive_student = create(:user, :student, student_pin: '3456')
      create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
      create(:classroom_membership, classroom: classroom, user: second_active_student, role: 'student')
      create(:classroom_membership, classroom: classroom, user: inactive_student, role: 'student', status: 'inactive')
      sign_in teacher

      patch classroom_member_student_pin_path(classroom),
            params: { student_pin: '4321' },
            headers: turbo_headers

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('target="modal"')
      expect(response.body).to include('target="flash"')
      expect(flash[:notice]).to eq(I18n.t('students.members.pin_reset.success', count: 2))
      expect(active_student.reload.authenticate_student_pin('4321')).to be_truthy
      expect(active_student.authenticate_student_pin('1234')).to be_falsey
      expect(second_active_student.reload.authenticate_student_pin('4321')).to be_truthy
      expect(inactive_student.reload.authenticate_student_pin('3456')).to be_truthy
      expect(inactive_student.authenticate_student_pin('4321')).to be_falsey
    end

    it 'lets an admin reset active student PINs' do
      active_student = create(:user, :student, student_pin: '1234')
      create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
      sign_in admin

      patch classroom_member_student_pin_path(classroom), params: { student_pin: '6789' }

      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(active_student.reload.authenticate_student_pin('6789')).to be_truthy
    end

    it 'rejects a teacher who does not manage the classroom' do
      active_student = create(:user, :student, student_pin: '1234')
      create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
      sign_in teacher

      patch classroom_member_student_pin_path(classroom), params: { student_pin: '4321' }

      expect(response).to redirect_to(root_path)
      expect(active_student.reload.authenticate_student_pin('1234')).to be_truthy
    end

    it 'rejects a student' do
      active_student = create(:user, :student, student_pin: '1234')
      create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
      sign_in active_student

      patch classroom_member_student_pin_path(classroom), params: { student_pin: '4321' }

      expect(response).to redirect_to(root_path)
      expect(active_student.reload.authenticate_student_pin('1234')).to be_truthy
    end

    it 'keeps the modal open when PIN is blank' do
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
      active_student = create(:user, :student, student_pin: '1234')
      create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
      sign_in teacher

      patch classroom_member_student_pin_path(classroom),
            params: { student_pin: '' },
            headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t('students.members.pin_reset.blank'))
      expect(response.body).to include('id="modal"')
      expect(active_student.reload.authenticate_student_pin('1234')).to be_truthy
    end

    it 'keeps the modal open when PIN is not four digits' do
      create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
      active_student = create(:user, :student, student_pin: '1234')
      create(:classroom_membership, classroom: classroom, user: active_student, role: 'student')
      sign_in teacher

      patch classroom_member_student_pin_path(classroom),
            params: { student_pin: '12ab' },
            headers: turbo_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t('students.members.pin_reset.invalid'))
      expect(active_student.reload.authenticate_student_pin('1234')).to be_truthy
    end
  end
end
