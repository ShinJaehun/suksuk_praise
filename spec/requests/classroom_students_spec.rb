require 'rails_helper'

RSpec.describe 'Classroom students', type: :request do
  include ActionView::RecordIdentifier

  let(:teacher) { create(:user, :teacher) }
  let(:classroom) { create(:classroom) }
  let(:turbo_headers) { { 'ACCEPT' => 'text/vnd.turbo-stream.html' } }

  before do
    create(:classroom_membership, user: teacher, classroom: classroom, role: 'teacher')
    sign_in teacher
  end

  describe 'GET /classrooms/:classroom_id/students/new' do
    it 'shows PIN fields without student password inputs' do
      get new_classroom_student_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('학생 개별 추가')
      expect(response.body).to include('name="user[student_pin]"')
      expect(response.body).not_to include('name="user[email]"')
      expect(response.body).not_to include('name="user[password]"')
      expect(response.body).not_to include('name="user[password_confirmation]"')
    end
  end

  describe 'POST /classrooms/:classroom_id/students' do
    it 'assigns a gendered avatar_key without reusing available keys in the classroom' do
      User::BOY_AVATAR_KEYS.first(22).each do |avatar_key|
        student = create(:user, :student, gender: 'boy', avatar_key: avatar_key)
        create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      end

      post classroom_students_path(classroom), params: {
        user: {
          name: '새 학생',
          student_pin: '1234',
          gender: 'boy'
        }
      }

      student = User.student.find_by!(name: '새 학생')
      expect(student.gender).to eq('boy')
      expect(student.avatar_key).to eq('boy23')
      expect(student.email).to be_nil
      expect(student.encrypted_password).to eq("")
      expect(student.authenticate_student_pin('1234')).to be_truthy
      expect(response).to redirect_to(classroom_path(classroom))
    end

    it 'creates a student and classroom membership without email or password params with turbo stream' do
      expect do
        post classroom_students_path(classroom),
             params: {
               user: {
                 name: '터보 학생',
                 student_pin: '2345',
                 gender: 'girl'
               }
             },
             headers: turbo_headers
      end.to change(User.student, :count).by(1)
                                         .and change(ClassroomMembership, :count).by(1)

      student = User.student.find_by!(name: '터보 학생')
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include(%(target="students_grid_#{classroom.id}"))
      expect(response.body).not_to include('target="student-management"')
      expect(classroom.classroom_memberships.exists?(user: student, role: 'student')).to eq(true)
      expect(student.email).to be_nil
      expect(student.encrypted_password).to eq("")
      expect(student.authenticate_student_pin('2345')).to be_truthy
    end

    it 'ignores submitted student email and Devise password params' do
      post classroom_students_path(classroom), params: {
        user: {
          name: '무비번 학생',
          email: 'ignored-student@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          student_pin: '4567',
          gender: 'girl'
        }
      }

      student = User.student.find_by!(name: '무비번 학생')
      expect(student.email).to be_nil
      expect(student.encrypted_password).to eq("")
      expect(student.authenticate_student_pin('4567')).to be_truthy
    end

    it 'creates a student and refreshes member management when submitted from members' do
      inactive_student = create(:user, :student, name: '기존 비활성 학생')
      create(:classroom_membership, user: inactive_student, classroom: classroom, role: 'student', status: 'inactive')

      expect do
        post classroom_students_path(classroom),
             params: {
               return_to: 'members',
               user: {
                 name: '구성원 학생',
                 student_pin: '3456',
                 gender: 'girl'
               }
             },
             headers: turbo_headers
      end.to change(User.student, :count).by(1)

      document = Nokogiri::HTML.fragment(response.body)
      student = User.student.find_by!(name: '구성원 학생')
      inactive_filter = document.at_css(
        %(a[href="#{classroom_members_path(classroom, status: 'inactive')}"])
      )

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('target="student-management"')
      expect(response.body).to include('구성원 학생')

      expect(response.body).not_to include('기존 비활성 학생')
      expect(response.body).not_to include(reactivate_classroom_student_path(classroom, inactive_student))
      expect(inactive_filter.text.squish).to eq('비활성 1')
      expect(response.body).to include(
        classroom_edit_member_student_names_path(classroom, status: 'active')
      )

      expect(response.body).to include(edit_classroom_student_path(classroom, student))
      expect(response.body).to include(deactivate_classroom_student_path(classroom, student))
      expect(response.body).to include('target="modal"')
      expect(student.email).to be_nil
      expect(student.encrypted_password).to eq("")
      expect(student.authenticate_student_pin('3456')).to be_truthy
    end

    it 'returns 422 with turbo stream when the student is invalid' do
      expect do
        post classroom_students_path(classroom),
             params: {
               user: {
                 name: '',
                 student_pin: '1234',
                 gender: 'boy'
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('target="modal"')
      expect(response.body).to include('이름')
    end

    it 'keeps validation errors inside the modal when submitted from members' do
      expect do
        post classroom_students_path(classroom),
             params: {
               return_to: 'members',
               user: {
                 name: '',
                 student_pin: '1234',
                 gender: 'boy'
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('target="modal"')
      expect(response.body).to include('name="return_to"')
      expect(response.body).to include('value="members"')
      expect(response.body).to include('이름')
    end

    it 'rejects a teacher outside the classroom' do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      expect do
        post classroom_students_path(classroom), params: {
          user: {
            name: '외부 생성',
            student_pin: '1234',
            gender: 'boy'
          }
        }
      end.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end

    it 'rejects a student' do
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      sign_out teacher
      sign_in student

      expect do
        post classroom_students_path(classroom), params: {
          user: {
            name: '학생 생성',
            student_pin: '1234',
            gender: 'girl'
          }
        }
      end.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe 'bulk student creation' do
    def draft_params
      {
        '0' => { name: '김학생', gender: 'boy', avatar_key: 'boy01' },
        '1' => { name: '이학생', gender: 'girl', avatar_key: 'girl01' }
      }
    end

    def turbo_frame_headers
      {
        'Turbo-Frame' => 'modal',
        'Accept' => 'text/html'
      }
    end

    it 'renders the setup modal without creating students' do
      expect do
        get bulk_new_classroom_students_path(classroom), headers: { 'Turbo-Frame' => 'modal' }
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="bulk-student-setup-form"')
      expect(response.body).to include('name="boy_count"', 'name="girl_count"', 'name="student_pin"')
      expect(response.body).to include('required="required"')
      expect(response.body).to include('이름 입력')
      expect(response.body).not_to include('name="user[email]"')
      expect(response.body).not_to include('name="user[password]"')
    end

    it 'previews student draft rows without writing to the database' do
      user_count = User.student.count
      membership_count = ClassroomMembership.count

      expect do
        post bulk_preview_classroom_students_path(classroom),
          params: { boy_count: 2, girl_count: 1, student_pin: '2468' },
          headers: turbo_frame_headers
      end.not_to change(User.student, :count)

      document = Nokogiri::HTML.fragment(response.body)
      rows = document.css('.bulk-student-draft-row')

      expect(ClassroomMembership.count).to eq(membership_count)
      expect(User.student.count).to eq(user_count)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="bulk-student-preview-form"')
      expect(rows.size).to eq(3)
      expect(response.body).to include('avatars/boy')
      expect(response.body).to include('avatars/girl')
      expect(response.body).to include('placeholder="이름"')
      expect(response.body).to include('삭제')
      expect(response.body).to include('name="students[0][gender]"')
      expect(response.body).to include('name="students[0][avatar_key]"')
      expect(response.body).not_to include('name="students[0][email]"')
      expect(response.body).not_to include('name="students[0][password]"')
      expect(response.request.fullpath).not_to include('2468')
    end

    it 'keeps setup values when preview validation fails' do
      expect do
        post bulk_preview_classroom_students_path(classroom),
          params: { boy_count: 0, girl_count: 0, student_pin: '12ab' },
          headers: turbo_frame_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('id="bulk-student-setup-form"')
      expect(response.body).to include('value="0"')
      expect(response.body).to include('value="12ab"')
      expect(response.body).to include('생성할 학생이 없습니다.')
    end

    it 'rejects preview when the PIN format is invalid' do
      post bulk_preview_classroom_students_path(classroom),
        params: { boy_count: 1, girl_count: 0, student_pin: '12ab' },
        headers: turbo_frame_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('초기 PIN은 4자리 숫자여야 합니다.')
    end

    it 'rejects preview when the PIN is blank' do
      post bulk_preview_classroom_students_path(classroom),
        params: { boy_count: 1, girl_count: 0, student_pin: '' },
        headers: turbo_frame_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('초기 PIN은 4자리 숫자여야 합니다.')
    end

    it 'rejects preview when the classroom would exceed the student limit' do
      29.times do |index|
        student = create(:user, :student, name: "기존 학생 #{index}")
        create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      end

      post bulk_preview_classroom_students_path(classroom),
        params: { boy_count: 2, girl_count: 0, student_pin: '2468' },
        headers: turbo_frame_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('최대 30명')
    end

    it 'allows preview when only active student memberships fit within the limit' do
      29.times do |index|
        student = create(:user, :student, name: "기존 활성 학생 #{index}")
        create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      end
      inactive_student = create(:user, :student, name: '기존 비활성 학생')
      create(:classroom_membership, user: inactive_student, classroom: classroom, role: 'student', status: 'inactive')

      post bulk_preview_classroom_students_path(classroom),
        params: { boy_count: 1, girl_count: 0, student_pin: '2468' },
        headers: turbo_frame_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="bulk-student-preview-form"')
    end

    it 'returns to setup from preview without exposing the PIN in the URL' do
      post bulk_preview_classroom_students_path(classroom),
        params: { back: '1', boy_count: 2, girl_count: 3, student_pin: '2468' },
        headers: turbo_frame_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="bulk-student-setup-form"')
      expect(response.body).to include('value="2"', 'value="3"', 'value="2468"')
      expect(response.request.fullpath).not_to include('2468')
    end

    it 'creates only submitted draft rows in a transaction' do
      expect do
        post bulk_create_classroom_students_path(classroom),
          params: {
            student_pin: '2468',
            students: draft_params.merge('2' => { name: '', gender: 'boy', avatar_key: 'boy02' }).except('2')
          }
      end.to change(User.student, :count).by(2)
        .and change(ClassroomMembership, :count).by(2)

      created_students = classroom.students.order(:created_at).last(2)

      expect(created_students.map(&:name)).to contain_exactly('김학생', '이학생')
      expect(created_students.map(&:gender)).to contain_exactly('boy', 'girl')
      expect(created_students.map(&:avatar_key)).to contain_exactly('boy01', 'girl01')
      expect(created_students.map(&:email)).to all(be_nil)
      expect(created_students.map(&:encrypted_password)).to all(eq(""))
      expect(created_students).to all(satisfy { |student| student.authenticate_student_pin('2468') })
      expect(classroom.classroom_memberships.where(user: created_students, role: 'student').pluck(:status)).to all(eq('active'))
      expect(flash[:notice]).to eq(I18n.t('students.bulk_create.success', count: 2))
    end

    it 'refreshes member management and closes the modal when submitted from members' do
      expect do
        post bulk_create_classroom_students_path(classroom),
          params: {
            return_to: 'members',
            student_pin: '1357',
            students: draft_params
          },
          headers: turbo_headers
      end.to change(User.student, :count).by(2)

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('target="student-management"')
      expect(response.body).to include('target="modal"')
      expect(response.body).to include('김학생', '이학생')
    end

    it 'rolls back when final submitted rows are invalid and keeps entered drafts visible' do
      expect do
        post bulk_create_classroom_students_path(classroom),
          params: {
            student_pin: '2468',
            students: {
              '0' => { name: '유지 학생', gender: 'boy', avatar_key: 'boy01' },
              '2' => { name: '', gender: 'girl', avatar_key: 'girl01' }
            }
          },
          headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('id="bulk-student-preview-form"')
      expect(response.body).to include('유지 학생')
      expect(response.body).to include('bulk_student_draft_0')
      expect(response.body).to include('bulk_student_draft_2')
      expect(response.body).not_to include('bulk_student_draft_1')
      expect(response.body).to include('이름을 입력해 주세요')
    end

    it 'does not create students when final submitted rows are empty' do
      expect do
        post bulk_create_classroom_students_path(classroom),
          params: { student_pin: '2468', students: {} },
          headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('생성할 학생이 없습니다.')
    end

    it 'does not create students when final PIN is blank' do
      expect do
        post bulk_create_classroom_students_path(classroom),
          params: {
            student_pin: '',
            students: draft_params
          },
          headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('초기 PIN은 4자리 숫자여야 합니다.')
    end

    it 'rolls back when final create would exceed the student limit' do
      29.times do |index|
        student = create(:user, :student, name: "기존 학생 #{index}")
        create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      end

      expect do
        post bulk_create_classroom_students_path(classroom),
          params: {
            student_pin: '2468',
            students: draft_params
          },
          headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('최대 30명')
    end

    it 'allows final create when inactive memberships do not exceed the active student limit' do
      29.times do |index|
        student = create(:user, :student, name: "기존 활성 학생 #{index}")
        create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      end
      inactive_student = create(:user, :student, name: '기존 비활성 학생')
      create(:classroom_membership, user: inactive_student, classroom: classroom, role: 'student', status: 'inactive')

      expect do
        post bulk_create_classroom_students_path(classroom),
          params: {
            student_pin: '2468',
            students: {
              '0' => { name: '추가 학생', gender: 'boy', avatar_key: 'boy01' }
            }
          }
      end.to change(User.student, :count).by(1)

      expect(User.student.find_by!(name: '추가 학생').authenticate_student_pin('2468')).to be_truthy
    end

    it 'rolls back when final avatar params are not valid for students' do
      expect do
        post bulk_create_classroom_students_path(classroom),
          params: {
            student_pin: '2468',
            students: {
              '0' => { name: '잘못된 학생', gender: 'boy', avatar_key: 'teacherM01' }
            }
          },
          headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('썸네일을 확인해 주세요')
    end

    it 'rolls back when final avatar and gender do not match' do
      expect do
        post bulk_create_classroom_students_path(classroom),
          params: {
            student_pin: '2468',
            students: {
              '0' => { name: '성별 불일치', gender: 'boy', avatar_key: 'girl01' }
            }
          },
          headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('썸네일을 확인해 주세요')
    end

    it 'ignores arbitrary role email and password params on final create' do
      post bulk_create_classroom_students_path(classroom),
        params: {
          student_pin: '2468',
          students: {
            '0' => {
              name: '보안 학생',
              gender: 'boy',
              avatar_key: 'boy01',
              role: 'admin',
              email: 'ignored@example.com',
              password: 'password123'
            }
          }
        }

      student = User.student.find_by!(name: '보안 학생')
      expect(student.role).to eq('student')
      expect(student.email).to be_nil
      expect(student.encrypted_password).to eq("")
    end

    it 'rejects a teacher outside the classroom' do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      expect do
        post bulk_preview_classroom_students_path(classroom), params: { boy_count: 1, girl_count: 1 }
      end.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end

    it 'allows an admin to preview drafts' do
      admin = create(:user, :admin)
      sign_out teacher
      sign_in admin

      post bulk_preview_classroom_students_path(classroom),
        params: { boy_count: 1, girl_count: 0, student_pin: '2468' },
        headers: turbo_frame_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="bulk-student-preview-form"')
    end

    it 'rejects a student' do
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      sign_out teacher
      sign_in student

      expect do
        post bulk_create_classroom_students_path(classroom), params: { students: draft_params }
      end.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end

    it 'rejects a guest' do
      sign_out teacher

      expect do
        post bulk_preview_classroom_students_path(classroom), params: { boy_count: 1, girl_count: 0 }
      end.not_to change(User.student, :count)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /classrooms/:classroom_id/students/:id' do
    let(:student) { create(:user, :student) }
    let!(:student_membership) do
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')
    end

    it 'shows the shared student profile card, navigation, and teacher operations' do
      create(:coupon_template, created_by: teacher, active: true)

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.xpath("//*[normalize-space(text())='학생 정보']")).to be_empty
      expect(response.body).to include(student.name)
      expect(response.body).to include(classroom.name)
      expect(response.body).to include('쿠폰 관리')
      expect(response.body).to include('한눈에 보기')
      expect(response.body).to include('학생 정보·PIN 수정')
      expect(response.body).to include('칭찬하기')
      expect(response.body).to include('교실로 돌아가기')
      expect(response.body).to include('쿠폰 지급')
      profile_card = document.at_css('[data-student-profile-card]')
      expect(profile_card.text).to include('쿠폰 지급')
      assignment_link = profile_card.at_css(
        %(a[href="#{coupon_assignment_classroom_student_path(classroom, student)}"])
      )
      expect(assignment_link['data-turbo-frame']).to eq(dom_id(student, :coupon_assignment))
      expect(response.body).not_to include('활성 쿠폰 중 하나를 가중치에 따라 랜덤으로 지급합니다.')
      expect(response.body).not_to include('선택한 쿠폰 지급')
      expect(response.body).to include(classroom_student_messages_path(classroom, student))
      expect(response.body).to include(dashboard_classroom_student_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
      coupon_navigation = document.at_css(%(a[href="#{classroom_student_path(classroom, student)}"]))
      expect(coupon_navigation['class']).to include('border-blue-500')
      expect(response.body).not_to include('user_message[body]')
      expect(response.body).not_to include('최근 발급 쿠폰')
      expect(response.body).not_to include('칭찬 타임라인')
    end

    it 'shows inactive status and hides operating actions for an inactive student' do
      student_membership.inactive!

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('ui.inactive'))
      expect(response.body).to include('쿠폰 관리')
      expect(response.body).to include('한눈에 보기')
      expect(response.body).to include('활동 기록')
      expect(response.body).to include('학생 정보·PIN 수정')
      expect(response.body).not_to include('칭찬하기')
      expect(response.body).not_to include('쿠폰 지급')
    end

    it 'does not allow an inactive student to view their own classroom detail' do
      student_membership.inactive!
      sign_out teacher
      sign_in student

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:not_found)
    end

    it 'shows pending coupon use requests as work to process' do
      template = create(:coupon_template, created_by: teacher)
      coupon = create(
        :user_coupon,
        user: student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher
      )
      create(
        :coupon_use_request,
        user_coupon: coupon,
        classroom: classroom,
        student: student,
        requested_by: student
      )

      get classroom_student_path(classroom, student)

      expect(response.body).to include('처리할 일')
      expect(response.body).to include('쿠폰 사용 요청 1건')
      expect(response.body).to include('사용 승인')
    end

    it 'hides message operations and the message section when messages are disabled' do
      classroom.update!(message_policy: 'disabled')

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(classroom_student_messages_path(classroom, student))
      expect(response.body).not_to include(dom_id(student, :message_section))
      expect(response.body).not_to include('user_message[body]')
    end

    it 'shows the same management operations to an admin' do
      admin = create(:user, :admin)
      sign_out teacher
      sign_in admin

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('학생 정보·PIN 수정')
      expect(response.body).to include('칭찬하기')
      expect(response.body).to include('교실로 돌아가기')
      expect(response.body).to include('쿠폰 지급')
      expect(response.body).to include(classroom_student_messages_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
    end

    it 'does not expose teacher management operations to the student' do
      sign_out teacher
      sign_in student

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('학생 정보·PIN 수정')
      expect(response.body).not_to include('칭찬하기')
      expect(response.body).not_to include('쿠폰 지급')
      expect(response.body).not_to include('선택한 쿠폰 지급')
      expect(response.body).not_to include('교실로 돌아가기')
      expect(response.body).to include('한눈에 보기')
      expect(response.body).to include(classroom_student_messages_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
    end

    it 'renders the coupon assignment card in its turbo frame' do
      create(:coupon_template, created_by: teacher, active: true)

      get coupon_assignment_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(dom_id(student, :coupon_assignment))
      expect(response.body).to include('활성 쿠폰 중 하나를 가중치에 따라 랜덤으로 지급합니다.')
      expect(response.body).to include('쿠폰 뽑기')
      expect(response.body).to include('선택한 쿠폰 지급')
      expect(response.body).to match(/value="쿠폰 지급"/)
    end

    it 'shows an empty assignment state when the teacher has no active templates' do
      get coupon_assignment_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('쿠폰 지급')
      expect(response.body).to include('지급 가능한 활성 쿠폰 템플릿이 없습니다.')
      expect(response.body).not_to include(classroom_student_coupons_path(classroom, student))
    end

    it 'rejects the student from loading the coupon assignment card' do
      sign_out teacher
      sign_in student

      get coupon_assignment_classroom_student_path(classroom, student)

      expect(response).to redirect_to(root_path)
    end

    it 'shows coupon and compliment history on the activity page' do
      template = create(:coupon_template, created_by: teacher, title: '기록 쿠폰')
      create(
        :user_coupon,
        user: student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher
      )
      create(:compliment, classroom: classroom, giver: teacher, receiver: student)

      get activity_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(response.body).to include(student.name)
      expect(response.body).to include('한눈에 보기')
      expect(response.body).to include(dashboard_classroom_student_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
      activity_navigation = document.at_css(%(a[href="#{activity_classroom_student_path(classroom, student)}"]))
      expect(activity_navigation['class']).to include('border-blue-500')
      expect(response.body).to include('최근 발급 쿠폰')
      expect(response.body).to include('기록 쿠폰')
      expect(response.body).to include('칭찬 타임라인')
      expect(response.body).to include(dom_id(student, :recent_issued_coupons))
      expect(response.body).to include(dom_id(student, :compliments))
      expect(response.body).not_to include('쿠폰 지급')
      expect(response.body).not_to include('쿠폰 뽑기')
      expect(response.body).not_to include('선택한 쿠폰 지급')
    end

    it 'allows the student to view their own activity page' do
      sign_out teacher
      sign_in student

      get activity_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('활동 기록')
      expect(response.body).to include('최근 발급 쿠폰')
      expect(response.body).to include('칭찬 타임라인')
    end

    it 'rejects a teacher outside the classroom from the activity page' do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      get activity_classroom_student_path(classroom, student)

      expect(response).to redirect_to(root_path)
    end
  end

  describe 'classroom-scoped student read boundaries' do
    let(:student) { create(:user, :student) }
    let(:past_classroom) { create(:classroom, school: classroom.school, name: '과거 학급') }

    before do
      create(:classroom_membership, user: student, classroom: classroom, role: 'student', status: 'active')
      create(:classroom_membership, user: student, classroom: past_classroom, role: 'student', status: 'inactive')
    end

    it 'allows the assigned teacher to view show and activity in the URL classroom' do
      [
        classroom_student_path(classroom, student),
        activity_classroom_student_path(classroom, student)
      ].each do |path|
        get path

        expect(response).to have_http_status(:ok)
      end
    end

    it 'rejects a teacher from show and activity in an unassigned URL classroom' do
      [
        classroom_student_path(past_classroom, student),
        activity_classroom_student_path(past_classroom, student)
      ].each do |path|
        get path

        expect(response).to redirect_to(root_path)
      end
    end

    it 'allows the past classroom teacher to view inactive student records' do
      past_teacher = create(:user, :teacher)
      create(:classroom_membership, user: past_teacher, classroom: past_classroom, role: 'teacher')
      sign_out teacher
      sign_in past_teacher

      [
        classroom_student_path(past_classroom, student),
        activity_classroom_student_path(past_classroom, student)
      ].each do |path|
        get path

        expect(response).to have_http_status(:ok)
      end
    end

    it 'allows an admin to view inactive student records' do
      sign_out teacher
      sign_in create(:user, :admin)

      get classroom_student_path(past_classroom, student)

      expect(response).to have_http_status(:ok)
    end

    it 'rejects an unassigned school manager' do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: past_classroom.school, user: manager)
      sign_out teacher
      sign_in manager

      get classroom_student_path(past_classroom, student)

      expect(response).to redirect_to(root_path)
    end

    it 'allows the student in the active classroom and rejects the inactive past classroom' do
      sign_out teacher
      sign_in student

      get classroom_student_path(classroom, student)
      expect(response).to have_http_status(:ok)

      get classroom_student_path(past_classroom, student)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /classrooms/:classroom_id/students/:id/edit' do
    it 'shows student PIN management without password inputs' do
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')

      get edit_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="user[student_pin]"')
      expect(response.body).not_to include('name="user[email]"')
      expect(response.body).not_to include('name="user[password]"')
      expect(response.body).not_to include('name="user[password_confirmation]"')
    end
  end

  describe 'PATCH /classrooms/:classroom_id/students/:id' do
    it 'reassigns avatar_key when gender changes and no custom avatar is attached' do
      student = create(:user, :student, gender: 'boy', avatar_key: 'boy01')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      User::GIRL_AVATAR_KEYS.first(16).each do |avatar_key|
        classmate = create(:user, :student, gender: 'girl', avatar_key: avatar_key)
        create(:classroom_membership, user: classmate, classroom: classroom, role: 'student')
      end

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          gender: 'girl'
        }
      }

      expect(student.reload.gender).to eq('girl')
      expect(student.avatar_key).to eq('girl17')
      expect(student.email).to be_nil
      expect(student.encrypted_password).to eq("")
      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
    end
  end

  describe 'PATCH /classrooms/:classroom_id/students/:id/deactivate' do
    it 'lets the classroom teacher deactivate a student without deleting records' do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      create(:compliment, classroom: classroom, giver: teacher, receiver: student)

      expect do
        patch deactivate_classroom_student_path(classroom, student)
      end.not_to change(User, :count)

      expect(membership.reload).to be_inactive
      expect(student.received_compliments.exists?).to eq(true)
      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(flash[:notice]).to eq(I18n.t('students.deactivate.success'))
    end

    it 'lets an admin deactivate a student' do
      admin = create(:user, :admin)
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      sign_out teacher
      sign_in admin

      expect do
        patch deactivate_classroom_student_path(classroom, student)
      end.not_to change(User, :count)

      expect(membership.reload).to be_inactive
    end

    it 'rejects a teacher outside the classroom' do
      outsider = create(:user, :teacher)
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      sign_out teacher
      sign_in outsider

      expect do
        patch deactivate_classroom_student_path(classroom, student)
      end.not_to change(User, :count)

      expect(response).to redirect_to(root_path)
      expect(membership.reload).to be_active
    end

    it 'rejects a student' do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      sign_out teacher
      sign_in student

      expect do
        patch deactivate_classroom_student_path(classroom, student)
      end.not_to change(User, :count)

      expect(response).to redirect_to(root_path)
      expect(membership.reload).to be_active
    end
  end

  describe 'PATCH /classrooms/:classroom_id/students/:id/reactivate' do
    it 'lets the classroom teacher reactivate an inactive student' do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                 status: 'inactive')

      patch reactivate_classroom_student_path(classroom, student)

      expect(membership.reload).to be_active
      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(flash[:notice]).to eq(I18n.t('students.reactivate.success'))
    end

    it 'lets an admin reactivate an inactive student' do
      admin = create(:user, :admin)
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                 status: 'inactive')
      sign_out teacher
      sign_in admin

      patch reactivate_classroom_student_path(classroom, student)

      expect(membership.reload).to be_active
    end

    it 'keeps both memberships unchanged when another classroom is already active' do
      student = create(:user, :student)
      active_classroom = create(:classroom)
      active_membership = create(:classroom_membership, user: student, classroom: active_classroom, role: 'student',
                                                        status: 'active')
      inactive_membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                          status: 'inactive')

      patch reactivate_classroom_student_path(classroom, student)

      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(flash[:alert]).to eq(I18n.t('students.reactivate.active_membership_conflict'))
      expect(active_membership.reload).to be_active
      expect(inactive_membership.reload).to be_inactive
    end

    it 'applies the same active membership conflict rule to an admin' do
      admin = create(:user, :admin)
      student = create(:user, :student)
      active_membership = create(:classroom_membership, user: student, classroom: create(:classroom), role: 'student',
                                                        status: 'active')
      inactive_membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                          status: 'inactive')
      sign_out teacher
      sign_in admin

      patch reactivate_classroom_student_path(classroom, student)

      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(flash[:alert]).to eq(I18n.t('students.reactivate.active_membership_conflict'))
      expect(active_membership.reload).to be_active
      expect(inactive_membership.reload).to be_inactive
    end

    it 'does not let the active classroom teacher reactivate the student in another classroom' do
      student = create(:user, :student)
      active_membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                        status: 'active')
      other_classroom = create(:classroom)
      inactive_membership = create(:classroom_membership, user: student, classroom: other_classroom, role: 'student',
                                                          status: 'inactive')

      patch reactivate_classroom_student_path(other_classroom, student)

      expect(response).to redirect_to(root_path)
      expect(active_membership.reload).to be_active
      expect(inactive_membership.reload).to be_inactive
    end

    it 'rejects a teacher outside the classroom' do
      outsider = create(:user, :teacher)
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                 status: 'inactive')
      sign_out teacher
      sign_in outsider

      patch reactivate_classroom_student_path(classroom, student)

      expect(membership.reload).to be_inactive
      expect(response).to redirect_to(root_path)
    end

    it 'rejects a student' do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                 status: 'inactive')
      sign_out teacher
      sign_in student

      patch reactivate_classroom_student_path(classroom, student)

      expect(membership.reload).to be_inactive
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'DELETE /classrooms/:classroom_id/students/:id' do
    it 'keeps direct delete calls from hard deleting a student' do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student')

      expect do
        delete classroom_student_path(classroom, student)
      end.not_to change(User, :count)

      expect(membership.reload).to be_inactive
      expect(response).to redirect_to(classroom_members_path(classroom))
    end
  end
end
