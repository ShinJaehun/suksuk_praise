require 'rails_helper'

RSpec.describe 'School teachers', type: :request do
  let(:school) { create(:school, name: '아라초등학교', color_key: 'orange') }
  let(:other_school) { create(:school, name: '다른초등학교') }
  let(:admin) { create(:user, :admin) }
  let(:manager) do
    create(:school_membership, :manager, school: school, user: create(:user, :teacher, name: '학교 관리자')).user
  end
  let(:member) { create(:school_membership, school: school, user: create(:user, :teacher, name: '일반 선생님')).user }
  let(:other_manager) { create(:school_membership, :manager, school: other_school, user: create(:user, :teacher)).user }

  def insert_legacy_teacher_membership!(user:, classroom:)
    ClassroomMembership.insert!({
                                  user_id: user.id,
                                  classroom_id: classroom.id,
                                  role: 'teacher',
                                  status: 'active',
                                  student_number: nil,
                                  created_at: Time.current,
                                  updated_at: Time.current
                                })
  end

  describe 'GET /schools/:school_id/teachers' do
    it "shows only the school's teachers, roles, classrooms, avatars, and page actions to its manager" do
      classroom = create(:classroom, school: school, grade: 4, name: '1반')
      later_classroom = create(:classroom, school: school, grade: 6, name: '기러기반')
      other_classroom = create(:classroom, school: other_school, name: '다른 학교 학급')
      unassigned_teacher = create(:user, :teacher, name: '미소속 선생님')
      create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
      create(:classroom_membership, classroom: later_classroom, user: manager, role: :teacher)
      other_teacher = create(:school_membership, school: other_school,
                                                 user: create(:user, :teacher, name: '다른 학교 선생님')).user
      student = create(:user, :student, name: '학생')
      school_member = member

      sign_in manager
      get school_teachers_path(school)

      document = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(school.name, manager.name, manager.email, school_member.name,
                                       '대표 선생님', '선생님', '4학년 1반', '6학년 기러기반', '담당 교실 없음')
      expect(document.at_css(%(img[alt="#{manager.name} avatar"]))).to be_present
      manager_row = document.at_xpath("//p[normalize-space()='#{manager.name}']/ancestor::article[1]")
      member_row = document.at_xpath("//p[normalize-space()='#{school_member.name}']/ancestor::article[1]")
      expect(manager_row['class']).to include('border-l-orange-400', 'bg-orange-50/60')
      expect(manager_row.at_css('.bg-emerald-100')&.text).to include('활성')
      expect(manager_row.at_css('.bg-violet-100')&.text&.strip).to eq('대표 선생님')
      expect(member_row.at_css('.bg-sky-100')&.text&.strip).to eq('선생님')
      expect(member_row.css('.bg-slate-100').map(&:text)).to include('담당 교실 없음')
      expect(manager_row.text).not_to include('담당 교실 2개')
      expect(manager_row.text.index('4학년 1반')).to be < manager_row.text.index('6학년 기러기반')
      new_link = document.at_css(%(a[href="#{new_school_teacher_path(school)}"]))
      edit_link = document.at_css(%(a[href="#{edit_school_teacher_path(school, manager)}"]))
      expect(new_link).to be_present
      expect(edit_link).to be_present
      expect(new_link['data-turbo-frame']).to be_nil
      expect(edit_link['data-turbo-frame']).to be_nil
      expect(document.at_css(%(form[action="#{school_teachers_path(school)}"][method="post"]))).to be_nil
      expect(document.at_css(%(form[action="#{school_teacher_path(school, manager)}"]))).to be_nil
      expect(response.body).not_to include(other_teacher.name, unassigned_teacher.name, student.name,
                                           other_classroom.name)
    end

    it 'filters teachers by active status' do
      active_member = member

      inactive_member = create(
        :school_membership,
        school: school,
        user: create(:user, :teacher, name: '비활성 선생님', active: false)
      ).user
      sign_in manager

      get school_teachers_path(school)
      expect(response.body).to include(active_member.name)
      expect(response.body).not_to include(inactive_member.name)

      get school_teachers_path(school, status: 'inactive')
      expect(response.body).to include(inactive_member.name)
      expect(response.body).not_to include(active_member.name)

      get school_teachers_path(school, status: 'all')
      expect(response.body).to include(member.name, inactive_member.name)
    end

    it 'blocks admins, members, other school managers, students, and guests' do
      sign_in admin
      get school_teachers_path(school)
      expect(response).to redirect_to(root_path)

      sign_in member
      get school_teachers_path(school)
      expect(response).to redirect_to(root_path)

      sign_in other_manager
      get school_teachers_path(school)
      expect(response).to have_http_status(:not_found)

      sign_in create(:user, :student)
      get school_teachers_path(school)
      expect(response).to have_http_status(:not_found)

      sign_out :user
      get school_teachers_path(school)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'PATCH teacher status' do
    it 'lets a manager deactivate and reactivate a member without removing memberships' do
      classroom = create(:classroom, school: school)
      classroom_membership = create(:classroom_membership, classroom: classroom, user: member, role: :teacher)
      school_membership = member.school_membership
      sign_in manager

      patch deactivate_school_teacher_path(school, member)

      expect(response).to redirect_to(school_teachers_path(school))
      expect(member.reload).to be_inactive
      expect(member.school_membership).to eq(school_membership)
      expect(member.classroom_memberships).to include(classroom_membership)

      patch reactivate_school_teacher_path(school, member, status: 'inactive')

      expect(response).to redirect_to(school_teachers_path(school, status: 'inactive'))
      expect(member.reload).to be_active
    end

    it "blocks self, another manager, and another school's teacher" do
      same_school_manager = create(
        :school_membership,
        :manager,
        school: school,
        user: create(:user, :teacher)
      ).user
      other_teacher = create(
        :school_membership,
        school: other_school,
        user: create(:user, :teacher)
      ).user
      sign_in manager

      patch deactivate_school_teacher_path(school, manager)
      expect(response).to redirect_to(root_path)

      patch deactivate_school_teacher_path(school, same_school_manager)
      expect(response).to redirect_to(root_path)

      patch deactivate_school_teacher_path(school, other_teacher)
      expect(response).to have_http_status(:not_found)
    end

    it 'blocks members, students, another manager, and guests' do
      inactive_target = create(
        :school_membership,
        school: school,
        user: create(:user, :teacher, active: false)
      ).user

      sign_in member

      patch deactivate_school_teacher_path(school, member)
      expect(response).to redirect_to(root_path)

      patch reactivate_school_teacher_path(school, inactive_target)
      expect(response).to redirect_to(root_path)

      sign_in create(:user, :student)

      patch deactivate_school_teacher_path(school, member)
      expect(response).to have_http_status(:not_found)

      sign_in other_manager

      patch deactivate_school_teacher_path(school, member)
      expect(response).to have_http_status(:not_found)

      sign_out :user

      patch deactivate_school_teacher_path(school, member)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'does not define a teacher delete route' do
      expect do
        Rails.application.routes.recognize_path(
          "/schools/#{school.id}/teachers/#{member.id}",
          method: :delete
        )
      end.to raise_error(ActionController::RoutingError)
    end
  end

  describe 'GET page forms' do
    it 'renders the new teacher form as a full page for the school manager' do
      classroom = create(:classroom, school: school, name: '우리 학교 1반')
      other_classroom = create(:classroom, school: other_school, name: '다른 학교 1반')
      sign_in manager

      get new_school_teacher_path(school)

      document = Nokogiri::HTML(response.body)
      form = document.at_css(%(form[action="#{school_teachers_path(school)}"]))
      avatar_key_input = form.at_css('input[name="user[avatar_key]"]')
      avatar_section = form.at_css('[data-teacher-avatar-preview-target="avatarSection"]')
      avatar_picker = form.at_css('[data-teacher-avatar-preview-target="picker"]')
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        I18n.t('schools.teachers.new_title'),
        school.name
      )
      expect(form).to be_present
      expect(form.text).to include('소속 학교', school.name, classroom.name)
      expect(form.text).not_to include(other_classroom.name)
      expect(form.at_css('select[name="school_id"], select[name="user[school_id]"]')).to be_nil
      expect(form.at_css('input[name="school_id"], input[name="user[school_id]"]')).to be_nil
      expect(form.at_css(%(input[name="classroom_ids[]"][value="#{classroom.id}"]))).to be_present
      expect(avatar_key_input['value']).to be_blank
      selected_gender = form.at_css('select[name="user[gender]"] option[selected]')&.[]('value')
      expect(selected_gender.to_s).to be_blank
      expect(avatar_section['hidden']).not_to be_nil
      expect(avatar_picker['hidden']).not_to be_nil
      expect(form['data-controller'].to_s.split).to include('teacher-avatar-preview')
      expect(form['data-teacher-avatar-preview-male-keys-value']).to be_present
      expect(form['data-teacher-avatar-preview-female-keys-value']).to be_present
      expect(form.at_css('select[name="user[gender]"][data-teacher-avatar-preview-target="gender"]')).to be_present
      expect(form.at_css('img[data-teacher-avatar-preview-target="image"]')).to be_present
      expect(form.at_css('[data-action="teacher-avatar-preview#togglePicker"]')).to be_present
      expect(form.at_css('[data-action="teacher-avatar-preview#select"]')).to be_present
      classroom_input = form.at_css(%(input[name="classroom_ids[]"][value="#{classroom.id}"]))
      expect(classroom_input['class']).to include('peer', 'sr-only')
      expect(classroom_input.ancestors('label').first['class']).to include('rounded-full', 'has-[:checked]:bg-blue-50')
    end

    it 'renders the edit teacher form as a full page with school classrooms' do
      classroom = create(:classroom, school: school, name: '1반')

      sign_in manager

      get edit_school_teacher_path(school, member)

      document = Nokogiri::HTML(response.body)
      teacher_form = document.at_css(%(form[action="#{school_teacher_path(school, member)}"]))
      info_card = document.at_xpath("//h2[normalize-space()='기본 정보']/ancestor::section[1]")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('선생님 정보 변경', member.name, school.name, classroom.name,
                                       '기본 정보', '계정 상태', '선생님')
      expect(info_card).to be_present
      expect(info_card.text).to include(member.name, member.email, school.name, '활성', '선생님')
      expect(info_card.at_css(%(img[alt="#{member.name} avatar"]))).to be_present
      expect(teacher_form).to be_present
      expect(teacher_form.at_css(%(input[name="classroom_ids[]"][value="#{classroom.id}"]))).to be_present
      expect(teacher_form.at_css('input[name="user[gender]"], input[name="user[avatar_key]"]')).to be_nil
      expect(document.at_css(%(form[action="#{deactivate_school_teacher_path(school, member)}"]))).to be_present
      expect(document.at_css('select[name="school_id"]')).to be_nil
      expect(document.at_css('select[name="user[school_id]"]')).to be_nil
      expect(document.at_css(%(a[href="#{school_teachers_path(school)}"]))).to be_present
    end

    it 'blocks members and managers from another school' do
      sign_in member
      get new_school_teacher_path(school)
      expect(response).to redirect_to(root_path)

      sign_in other_manager
      get edit_school_teacher_path(school, member)
      expect(response).to have_http_status(:not_found)
    end

    it 'blocks an admin from every school teacher page action' do
      sign_in admin

      get new_school_teacher_path(school)
      expect(response).to redirect_to(root_path)

      get edit_school_teacher_path(school, member)
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST /schools/:school_id/teachers' do
    it 'creates a member teacher without classroom assignments for the URL school' do
      create(:coupon_template, created_by: admin, bucket: 'library', active: true, title: '기본 쿠폰')

      sign_in manager
      post school_teachers_path(school), params: {
        user: valid_teacher_params(email: 'school-teacher@example.com'),
        classroom_ids: [''],
        school_id: other_school.id
      }

      created_teacher = User.teacher.find_by!(email: 'school-teacher@example.com')
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(school_teachers_path(school))
      expect(created_teacher.role).to eq('teacher')
      expect(created_teacher.school_membership).to have_attributes(school: school, role: 'member')
      expect(created_teacher.classroom_memberships.teacher).to be_empty
      expect(CouponTemplate.personal_for(created_teacher)).to be_empty
    end

    it 'creates assignments for multiple selected classrooms in the URL school' do
      selected_classrooms = create_list(:classroom, 2, school: school)
      unselected_classroom = create(:classroom, school: school)
      sign_in manager

      post school_teachers_path(school), params: {
        user: valid_teacher_params(email: 'assigned-school-teacher@example.com'),
        classroom_ids: selected_classrooms.map(&:id)
      }

      created_teacher = User.teacher.find_by!(email: 'assigned-school-teacher@example.com')
      expect(response).to redirect_to(school_teachers_path(school))
      expect(flash[:notice]).to eq(I18n.t('schools.teachers.create.success'))
      expect(created_teacher.school_membership).to have_attributes(school: school, role: 'member')
      expect(created_teacher.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(
        *selected_classrooms.map(&:id)
      )
      expect(created_teacher.classroom_memberships.teacher.exists?(classroom: unselected_classroom)).to eq(false)
    end

    it 'rolls back and renders the new page with submitted values on validation failure' do
      classroom = create(:classroom, school: school)
      sign_in manager

      expect do
        post school_teachers_path(school),
             params: {
               user: valid_teacher_params(name: '', email: 'invalid-school-teacher@example.com'),
               classroom_ids: [classroom.id]
             },
             headers: { 'Accept' => Mime[:turbo_stream].to_s }
      end.not_to(change { [User.count, SchoolMembership.count, CouponTemplate.count] })

      document = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq('text/html')
      expect(response.body).to include(
        I18n.t('schools.teachers.new_title'),
        school.name
      )
      expect(document.at_css('input[name="user[email]"]')['value']).to eq('invalid-school-teacher@example.com')
      expect(response.body).to include('<option selected="selected" value="female">여자</option>')
      expect(document.at_css('input[name="user[avatar_key]"]')['value']).to eq('teacherF01')
      expect(document.at_css('img[data-teacher-avatar-preview-target="image"]')['src']).to include('teacherF01')
      expect(document.at_css(%(input[name="classroom_ids[]"][value="#{classroom.id}"][checked]))).to be_present
      expect(document.at_css('select[name="school_id"], select[name="user[school_id]"]')).to be_nil
    end

    it 'rejects classrooms outside the URL school without partial creation' do
      valid_classroom = create(:classroom, school: school)
      other_classroom = create(:classroom, school: other_school)
      sign_in manager

      expect do
        post school_teachers_path(school), params: {
          user: valid_teacher_params(email: 'invalid-assignment@example.com'),
          classroom_ids: [valid_classroom.id, other_classroom.id]
        }
      end.not_to(change { [User.count, SchoolMembership.count, ClassroomMembership.count] })

      document = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(
        I18n.t('schools.teachers.new_title'),
        I18n.t('schools.teachers.errors.classroom_not_found')
      )
      expect(document.at_css(%(input[name="classroom_ids[]"][value="#{valid_classroom.id}"][checked]))).to be_present
    end

    it 'rejects a missing classroom without partial creation' do
      valid_classroom = create(:classroom, school: school)
      missing_classroom_id = Classroom.maximum(:id).to_i + 10_000
      sign_in manager

      expect do
        post school_teachers_path(school), params: {
          user: valid_teacher_params(email: 'missing-assignment@example.com'),
          classroom_ids: [valid_classroom.id, missing_classroom_id]
        }
      end.not_to(change { [User.count, SchoolMembership.count, ClassroomMembership.count] })

      document = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('선택한 교실을 찾을 수 없습니다.')
      expect(document.at_css(%(input[name="classroom_ids[]"][value="#{valid_classroom.id}"][checked]))).to be_present
    end

    it 'blocks direct posts outside the allowed school scope' do
      [admin, other_manager, member, create(:user, :student)].each do |actor|
        sign_in actor

        expect do
          post school_teachers_path(school),
               params: { user: valid_teacher_params(email: "blocked-#{actor.id}@example.com") }
        end.not_to(change { User.teacher.count })
      end
    end

    it 'requires authentication' do
      post school_teachers_path(school), params: { user: valid_teacher_params(email: 'guest@example.com') }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'PATCH /schools/:school_id/teachers/:id' do
    it "adds and removes only the school's classroom assignments" do
      first_classroom = create(:classroom, school: school, name: '1반')
      second_classroom = create(:classroom, school: school, name: '2반')
      other_classroom = create(:classroom, school: other_school, name: '다른 학교')
      create(:classroom_membership, classroom: first_classroom, user: member, role: :teacher)
      insert_legacy_teacher_membership!(user: member, classroom: other_classroom)
      membership = member.school_membership
      sign_in manager

      patch school_teacher_path(school, member), params: { classroom_ids: [second_classroom.id] }

      expect(response).to redirect_to(school_teachers_path(school))
      expect(member.reload.school_membership).to eq(membership)
      expect(membership.reload).to be_member
      expect(member.classroom_memberships.teacher.where(classroom: first_classroom)).to be_empty
      expect(member.classroom_memberships.teacher.exists?(classroom: second_classroom)).to eq(true)
      expect(member.classroom_memberships.teacher.exists?(classroom: other_classroom)).to eq(true)

      patch school_teacher_path(school, member), params: { classroom_ids: [''] }

      expect(response).to redirect_to(school_teachers_path(school))
      expect(member.classroom_memberships.teacher.where(classroom: [first_classroom, second_classroom])).to be_empty
      expect(member.classroom_memberships.teacher.exists?(classroom: other_classroom)).to eq(true)
    end

    it 'keeps manager role while updating assignments' do
      classroom = create(:classroom, school: school)
      sign_in manager

      patch school_teacher_path(school, manager), params: { classroom_ids: [classroom.id] }

      expect(response).to redirect_to(school_teachers_path(school))
      expect(manager.reload.school_membership).to be_manager
      expect(manager.classroom_memberships.teacher.exists?(classroom: classroom)).to eq(true)
    end

    it 'rejects another school or malformed classroom id without partial changes' do
      existing_classroom = create(:classroom, school: school)
      valid_classroom = create(:classroom, school: school)
      other_classroom = create(:classroom, school: other_school)
      create(:classroom_membership, classroom: existing_classroom, user: member, role: :teacher)
      sign_in manager

      patch school_teacher_path(school, member),
            params: { classroom_ids: [valid_classroom.id, other_classroom.id] },
            headers: { 'Accept' => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:unprocessable_content)
      document = Nokogiri::HTML(response.body)
      expect(response.media_type).to eq('text/html')
      expect(response.body).to include('선생님 정보 변경', '선택한 교실을 찾을 수 없습니다.')
      expect(document.at_css(%(input[name="classroom_ids[]"][value="#{valid_classroom.id}"][checked]))).to be_present
      expect(member.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(existing_classroom.id)

      patch school_teacher_path(school, member), params: { classroom_ids: ['abc'] }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('<!DOCTYPE html>')
      expect(member.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(existing_classroom.id)
    end

    it 'returns 404 when editing users outside the URL school' do
      unassigned_teacher = create(:user, :teacher)
      other_teacher = create(:school_membership, school: other_school, user: create(:user, :teacher)).user
      student = create(:user, :student)

      [unassigned_teacher, other_teacher, student].each do |user|
        sign_in manager

        get edit_school_teacher_path(school, user)

        expect(response).to have_http_status(:not_found)
      end
    end

    it 'returns 404 when updating users outside the URL school' do
      unassigned_teacher = create(:user, :teacher)
      other_teacher = create(:school_membership, school: other_school, user: create(:user, :teacher)).user
      student = create(:user, :student)

      [unassigned_teacher, other_teacher, student].each do |user|
        sign_in manager

        patch school_teacher_path(school, user), params: { classroom_ids: [''] }

        expect(response).to have_http_status(:not_found)
      end
    end

    it 'blocks direct patches outside the allowed school scope' do
      classroom = create(:classroom, school: school)

      sign_in other_manager
      patch school_teacher_path(school, member), params: { classroom_ids: [classroom.id] }
      expect(response).to have_http_status(:not_found)

      sign_in member
      patch school_teacher_path(school, member), params: { classroom_ids: [classroom.id] }
      expect(response).to redirect_to(root_path)

      sign_in admin
      patch school_teacher_path(school, member), params: { classroom_ids: [classroom.id] }
      expect(response).to redirect_to(root_path)
    end
  end

  def valid_teacher_params(email:, name: '새 교사')
    {
      name: name,
      email: email,
      password: 'password123',
      password_confirmation: 'password123',
      gender: 'female',
      avatar_key: 'teacherF01'
    }
  end
end
