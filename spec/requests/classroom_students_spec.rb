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

  def create_active_students(count, classroom:)
    count.times do |index|
      student = create(:user, :student, name: "기존 활성 학생 #{index}")
      create(:classroom_membership, user: student, classroom: classroom, role: 'student', status: 'active')
    end
  end

  describe 'GET /classrooms/:id roster' do
    it 'shows active students in current-classroom roster order' do
      students = [
        create(:user, :student, name: '5번 학생', gender: 'girl'),
        create(:user, :student, name: '번호 없음 B', gender: 'boy'),
        create(:user, :student, name: '1번 학생', gender: 'boy'),
        create(:user, :student, name: '2번 학생', gender: 'girl'),
        create(:user, :student, name: '번호 없음 A', gender: 'girl')
      ]
      [5, nil, 1, 2, nil].each_with_index do |number, index|
        create(:classroom_membership,
          classroom: classroom,
          user: students[index],
          role: 'student',
          status: 'active',
          student_number: number)
      end
      past_classroom = create(:classroom)
      create(:classroom_membership,
        classroom: past_classroom,
        user: students[2],
        role: 'student',
        status: 'inactive',
        student_number: 12)
      inactive_student = create(:user, :student, name: '현재 비활성 학생')
      create(:classroom_membership,
        classroom: classroom,
        user: inactive_student,
        role: 'student',
        status: 'inactive',
        student_number: 3)

      get classroom_path(classroom)

      cards = Nokogiri::HTML(response.body).css('[data-student-card]')
      expect(cards.map { |card| card['data-student-id'].to_i }).to eq(
        [students[2], students[3], students[0], students[4], students[1]].map(&:id)
      )
      expect(cards.map { |card| card.at_css('[data-student-number]').text.squish }).to eq(
        ['1번', '2번', '5번', '번호 미지정', '번호 미지정']
      )
      expect(response.body).not_to include(inactive_student.name, '12번')
    end
  end

  describe 'GET /classrooms/:classroom_id/students/new' do
    it 'shows PIN fields without student password inputs' do
      get new_classroom_student_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('학생 개별 추가')
      expect(response.body).to include('name="classroom_membership[student_number]"')
      expect(response.body).to include('name="user[student_pin]"')
      expect(response.body).to include('required="required"')
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
        classroom_membership: { student_number: 1 },
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
      expect(student.encrypted_password).to eq('')
      expect(student.authenticate_student_pin('1234')).to be_truthy
      expect(response).to redirect_to(classroom_path(classroom))
    end

    it 'creates a student and classroom membership without email or password params with turbo stream' do
      expect do
        post classroom_students_path(classroom),
             params: {
               classroom_membership: { student_number: 1 },
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
      expect(response.body).to include(%(target="students_list_#{classroom.id}"))
      expect(response.body).not_to include('target="student-management"')
      expect(response.body).to include('data-student-card', '1번')
      expect(classroom.classroom_memberships.exists?(user: student, role: 'student')).to eq(true)
      expect(classroom.classroom_memberships.find_by!(user: student).student_number).to eq(1)
      expect(student.email).to be_nil
      expect(student.encrypted_password).to eq('')
      expect(student.authenticate_student_pin('2345')).to be_truthy
    end

    it 'ignores submitted student email and Devise password params' do
      post classroom_students_path(classroom), params: {
        classroom_membership: { student_number: 1 },
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
      expect(student.encrypted_password).to eq('')
      expect(student.authenticate_student_pin('4567')).to be_truthy
    end

    it 'creates a student and refreshes member management when submitted from members' do
      inactive_student = create(:user, :student, name: '기존 비활성 학생')
      create(:classroom_membership, user: inactive_student, classroom: classroom, role: 'student', status: 'inactive')

      expect do
        post classroom_students_path(classroom),
             params: {
               return_to: 'members',
               classroom_membership: { student_number: 1 },
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
      expect(response.body).to include('1번')

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
      expect(student.encrypted_password).to eq('')
      expect(student.authenticate_student_pin('3456')).to be_truthy
    end

    it 'returns 422 with turbo stream when the student is invalid' do
      expect do
        post classroom_students_path(classroom),
             params: {
               classroom_membership: { student_number: 1 },
               user: {
                 name: '',
                 student_pin: '1234',
                 gender: 'boy'
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('target="modal"')
      expect(response.body).to include('이름')
    end

    it 'keeps validation errors inside the modal when submitted from members' do
      expect do
        post classroom_students_path(classroom),
             params: {
               return_to: 'members',
               classroom_membership: { student_number: 1 },
               user: {
                 name: '',
                 student_pin: '1234',
                 gender: 'boy'
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
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
          classroom_membership: { student_number: 1 },
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
          classroom_membership: { student_number: 1 },
          user: {
            name: '학생 생성',
            student_pin: '1234',
            gender: 'girl'
          }
        }
      end.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end

    it 'allows creating one student when the classroom has 29 active students' do
      create_active_students(29, classroom: classroom)

      expect do
        post classroom_students_path(classroom), params: {
          classroom_membership: { student_number: 1 },
          user: {
            name: '30번째 학생',
            student_pin: '1234',
            gender: 'boy'
          }
        }
      end.to change(User.student, :count).by(1)

      expect(response).to redirect_to(classroom_path(classroom))
    end

    it 'rejects creating one student when the classroom already has 30 active students' do
      create_active_students(30, classroom: classroom)

      expect do
        post classroom_students_path(classroom), params: {
          classroom_membership: { student_number: 1 },
          user: {
            name: '초과 학생',
            student_pin: '1234',
            gender: 'girl'
          }
        }
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('최대 30명')
      expect(User.find_by(name: '초과 학생')).to be_nil
    end

    it 'does not count inactive students toward the individual create limit' do
      create_active_students(29, classroom: classroom)
      inactive_student = create(:user, :student, name: '기존 비활성 학생')
      create(:classroom_membership, user: inactive_student, classroom: classroom, role: 'student', status: 'inactive')

      expect do
        post classroom_students_path(classroom), params: {
          classroom_membership: { student_number: 1 },
          user: {
            name: '활성 추가 학생',
            student_pin: '1234',
            gender: 'girl'
          }
        }
      end.to change(User.student, :count).by(1)

      expect(response).to redirect_to(classroom_path(classroom))
    end

    it 'rejects blank PIN values on individual create' do
      expect do
        post classroom_students_path(classroom),
             params: {
               classroom_membership: { student_number: 1 },
               user: {
                 name: 'PIN 없는 학생',
                 student_pin: '',
                 gender: 'boy'
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('target="modal"')
      expect(response.body).to include('PIN은 4자리 숫자여야 합니다.')
    end

    it 'rejects invalid PIN values on individual create' do
      expect do
        post classroom_students_path(classroom),
             params: {
               classroom_membership: { student_number: 1 },
               user: {
                 name: 'PIN 오류 학생',
                 student_pin: '12ab',
                 gender: 'girl'
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('PIN은 4자리 숫자여야 합니다.')
    end

    it 'requires a positive integer student number on individual create' do
      [
        ['', '출석번호를 입력해 주세요.'],
        ['0', '출석번호는 1 이상의 정수여야 합니다.'],
        ['-1', '출석번호는 1 이상의 정수여야 합니다.'],
        ['1.5', '출석번호는 1 이상의 정수여야 합니다.'],
        ['abc', '출석번호는 1 이상의 정수여야 합니다.']
      ].each do |student_number, message|
        expect do
          post classroom_students_path(classroom),
               params: {
                 classroom_membership: { student_number: student_number },
                 user: { name: '번호 오류 학생', student_pin: '1234', gender: 'boy' }
               },
               headers: turbo_headers
        end.not_to change(User.student, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(message)
        expect(response.body).to include(%(value="#{student_number}")) if student_number.present?
      end
    end

    it 'rejects a student number used by another active student in the classroom' do
      existing = create(:user, :student)
      create(:classroom_membership,
             user: existing,
             classroom: classroom,
             role: 'student',
             status: 'active',
             student_number: 7)

      membership_count = ClassroomMembership.count
      expect do
        post classroom_students_path(classroom),
             params: {
               classroom_membership: { student_number: 7 },
               user: { name: '중복 번호 학생', student_pin: '1234', gender: 'girl' }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('7번 출석번호는 이미 사용 중입니다.')
      expect(User.find_by(name: '중복 번호 학생')).to be_nil
      expect(ClassroomMembership.count).to eq(membership_count)
    end

    it 'allows the same student number in another classroom' do
      other_classroom = create(:classroom)
      other_student = create(:user, :student)
      create(:classroom_membership,
             user: other_student,
             classroom: other_classroom,
             role: 'student',
             status: 'active',
             student_number: 7)

      post classroom_students_path(classroom), params: {
        classroom_membership: { student_number: 7 },
        user: { name: '다른 교실 번호 학생', student_pin: '1234', gender: 'boy' }
      }

      student = User.find_by!(name: '다른 교실 번호 학생')
      expect(classroom.classroom_memberships.find_by!(user: student).student_number).to eq(7)
      expect(response).to redirect_to(classroom_path(classroom))
    end

    it 'turns a student number database race into a form error and rolls back the user' do
      allow_any_instance_of(ClassroomMembership).to receive(:save!)
        .and_raise(ActiveRecord::RecordNotUnique)

      expect do
        post classroom_students_path(classroom),
             params: {
               classroom_membership: { student_number: 7 },
               user: { name: '경쟁 충돌 학생', student_pin: '1234', gender: 'boy' }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('7번 출석번호는 이미 사용 중입니다.')
      expect(User.find_by(name: '경쟁 충돌 학생')).to be_nil
    end

    it 'rolls back the user when classroom membership creation fails' do
      invalid_membership = build(:classroom_membership, classroom: classroom, role: 'student')
      invalid_membership.errors.add(:base, 'membership failed')
      allow_any_instance_of(ClassroomMembership).to receive(:save!).and_raise(
        ActiveRecord::RecordInvalid.new(invalid_membership)
      )

      expect do
        post classroom_students_path(classroom),
             params: {
               classroom_membership: { student_number: 1 },
               user: {
                 name: '롤백 학생',
                 student_pin: '1234',
                 gender: 'boy'
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('target="modal"')
      expect(User.find_by(name: '롤백 학생')).to be_nil
    end
  end

  describe 'bulk student creation' do
    def draft_params
      {
        '0' => { student_number: '1', name: '김학생', gender: 'girl', avatar_key: 'girl01' },
        '1' => { student_number: '2', name: '이학생', gender: 'boy', avatar_key: 'boy01' }
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
      expect(response.body).to include('name="student_count"', 'name="student_pin"')
      expect(response.body).not_to include('name="boy_count"', 'name="girl_count"')
      expect(response.body).to include('required="required"')
      expect(response.body).to include('명단 만들기')
      expect(response.body).not_to include('name="user[email]"')
      expect(response.body).not_to include('name="user[password]"')
    end

    it 'previews student draft rows without writing to the database' do
      user_count = User.student.count
      membership_count = ClassroomMembership.count

      expect do
        post bulk_preview_classroom_students_path(classroom),
             params: { student_count: 3, student_pin: '2468', boy_count: 30, girl_count: 30 },
             headers: turbo_frame_headers
      end.not_to change(User.student, :count)

      document = Nokogiri::HTML.fragment(response.body)
      rows = document.css('#bulk-student-draft-list > .bulk-student-draft-row')

      expect(ClassroomMembership.count).to eq(membership_count)
      expect(User.student.count).to eq(user_count)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="bulk-student-preview-form"')
      expect(rows.size).to eq(3)
      expect(response.body).to include('placeholder="이름"')
      expect(response.body).to include('삭제')
      expect(response.body).to include('name="students[0][student_number]"')
      expect(response.body).to include('name="students[0][gender]"')
      expect(response.body).to include('name="students[0][avatar_key]"')
      expect(response.body).to include('data-bulk-student-draft-target="studentCount"')
      expect(response.body).to include('value="1"', 'value="2"', 'value="3"')
      expect(response.body).to include('bulk-student-draft#selectGender')
      expect(response.body).to include('bulk-student-draft#add', 'bulk-student-draft#remove')
      expect(response.body).not_to include('name="students[0][email]"')
      expect(response.body).not_to include('name="students[0][password]"')
      expect(response.request.fullpath).not_to include('2468')
    end

    it 'keeps setup values when preview validation fails' do
      expect do
        post bulk_preview_classroom_students_path(classroom),
             params: { student_count: 0, student_pin: '12ab' },
             headers: turbo_frame_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('id="bulk-student-setup-form"')
      expect(response.body).to include('value="0"')
      expect(response.body).to include('value="12ab"')
      expect(response.body).to include('등록할 학생 수는 1 이상의 정수여야 합니다.')
    end

    it 'rejects invalid student counts without using legacy gender counts' do
      ['', '0', '-1', '1.5', 'abc'].each do |student_count|
        post bulk_preview_classroom_students_path(classroom),
             params: {
               student_count: student_count,
               student_pin: '2468',
               boy_count: 10,
               girl_count: 10
             },
             headers: turbo_frame_headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('등록할 학생 수는 1 이상의 정수여야 합니다.')
      end
    end

    it 'rejects preview when the PIN format is invalid' do
      post bulk_preview_classroom_students_path(classroom),
           params: { student_count: 1, student_pin: '12ab' },
           headers: turbo_frame_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('초기 PIN은 4자리 숫자여야 합니다.')
    end

    it 'rejects preview when the PIN is blank' do
      post bulk_preview_classroom_students_path(classroom),
           params: { student_count: 1, student_pin: '' },
           headers: turbo_frame_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('초기 PIN은 4자리 숫자여야 합니다.')
    end

    it 'rejects preview when the classroom would exceed the student limit' do
      29.times do |index|
        student = create(:user, :student, name: "기존 학생 #{index}")
        create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      end

      post bulk_preview_classroom_students_path(classroom),
           params: { student_count: 2, student_pin: '2468' },
           headers: turbo_frame_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('최대 30명')
    end

    it 'allows preview when only active student memberships fit within the limit' do
      create_active_students(29, classroom: classroom)
      inactive_student = create(:user, :student, name: '기존 비활성 학생')
      create(:classroom_membership, user: inactive_student, classroom: classroom, role: 'student', status: 'inactive')

      post bulk_preview_classroom_students_path(classroom),
           params: { student_count: 1, student_pin: '2468' },
           headers: turbo_frame_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="bulk-student-preview-form"')
    end

    it 'rejects final create when active students changed after preview' do
      create_active_students(28, classroom: classroom)

      post bulk_preview_classroom_students_path(classroom),
           params: { student_count: 2, student_pin: '2468' },
           headers: turbo_frame_headers

      expect(response).to have_http_status(:ok)

      added_student = create(:user, :student, name: '중간 추가 학생')
      create(:classroom_membership, user: added_student, classroom: classroom, role: 'student', status: 'active')

      expect do
        post bulk_create_classroom_students_path(classroom),
             params: {
               student_pin: '2468',
               students: {
                 '0' => { student_number: '1', name: '최종 학생 1', gender: 'boy', avatar_key: 'boy01' },
                 '1' => { student_number: '2', name: '최종 학생 2', gender: 'boy', avatar_key: 'boy02' }
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('최대 30명')
    end

    it 'returns to setup from preview without exposing the PIN in the URL' do
      post bulk_preview_classroom_students_path(classroom),
           params: { back: '1', student_count: 5, student_pin: '2468' },
           headers: turbo_frame_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="bulk-student-setup-form"')
      expect(response.body).to include('value="5"', 'value="2468"')
      expect(response.request.fullpath).not_to include('2468')
    end

    it 'creates only submitted draft rows in a transaction' do
      expect do
        post bulk_create_classroom_students_path(classroom),
             params: {
               student_pin: '2468',
               students: draft_params.merge(
                 '2' => { student_number: '3', name: '', gender: 'boy', avatar_key: 'boy02' }
               ).except('2')
             }
      end.to change(User.student, :count).by(2)
                                         .and change(ClassroomMembership, :count).by(2)

      created_students = classroom.students.order(:created_at).last(2)

      expect(created_students.map(&:name)).to contain_exactly('김학생', '이학생')
      expect(created_students.map(&:gender)).to contain_exactly('boy', 'girl')
      expect(created_students.map(&:avatar_key)).to contain_exactly('boy01', 'girl01')
      expect(created_students.map(&:email)).to all(be_nil)
      expect(created_students.map(&:encrypted_password)).to all(eq(''))
      expect(created_students).to all(satisfy { |student| student.authenticate_student_pin('2468') })
      expect(classroom.classroom_memberships.where(user: created_students,
                                                   role: 'student').pluck(:status)).to all(eq('active'))
      expect(classroom.classroom_memberships.where(user: created_students).pluck(:student_number)).to contain_exactly(
        1, 2
      )
      expect(flash[:notice]).to eq(I18n.t('students.bulk_create.success', count: 2))
    end

    it 'creates a mixed-gender nonconsecutive roster in submitted row order' do
      roster = {
        'a' => { student_number: '1', name: '첫째', gender: 'girl', avatar_key: 'girl01' },
        'b' => { student_number: '2', name: '둘째', gender: 'boy', avatar_key: 'boy01' },
        'c' => { student_number: '5', name: '셋째', gender: 'girl', avatar_key: 'girl02' },
        'd' => { student_number: '3', name: '넷째', gender: 'boy', avatar_key: 'boy02' }
      }

      expect do
        post bulk_create_classroom_students_path(classroom),
             params: { student_pin: '2468', students: roster }
      end.to change(User.student, :count).by(4)
                                         .and change(ClassroomMembership, :count).by(4)

      memberships = classroom.classroom_memberships.student
                             .joins(:user)
                             .where(users: { name: %w[첫째 둘째 셋째 넷째] })
                             .pluck('users.name', :student_number)
                             .to_h
      expect(memberships).to eq('첫째' => 1, '둘째' => 2, '셋째' => 5, '넷째' => 3)
      expect(User.where(name: %w[첫째 둘째 셋째 넷째])).to all(
        satisfy { |student| student.authenticate_student_pin('2468') }
      )
    end

    it 'rejects each invalid roster field and preserves the submitted row' do
      invalid_rows = [
        [{ student_number: '', name: '학생', gender: 'boy', avatar_key: 'boy01' }, '출석번호를 입력해 주세요.'],
        [{ student_number: '0', name: '학생', gender: 'boy', avatar_key: 'boy01' }, '출석번호는 1 이상의 정수여야 합니다.'],
        [{ student_number: '-1', name: '학생', gender: 'boy', avatar_key: 'boy01' }, '출석번호는 1 이상의 정수여야 합니다.'],
        [{ student_number: '1.5', name: '학생', gender: 'boy', avatar_key: 'boy01' }, '출석번호는 1 이상의 정수여야 합니다.'],
        [{ student_number: 'abc', name: '학생', gender: 'boy', avatar_key: 'boy01' }, '출석번호는 1 이상의 정수여야 합니다.'],
        [{ student_number: '7', name: '', gender: 'boy', avatar_key: 'boy01' }, '이름을 입력해 주세요.'],
        [{ student_number: '7', name: '학생', gender: '', avatar_key: '' }, '성별을 선택해 주세요.'],
        [{ student_number: '7', name: '학생', gender: 'other', avatar_key: 'boy01' }, '성별을 선택해 주세요.'],
        [{ student_number: '7', name: '학생', gender: 'boy', avatar_key: '' }, '썸네일을 선택해 주세요.'],
        [{ student_number: '7', name: '학생', gender: 'boy', avatar_key: 'girl01' }, '썸네일을 확인해 주세요.']
      ]

      invalid_rows.each do |row, message|
        membership_count = ClassroomMembership.count
        expect do
          post bulk_create_classroom_students_path(classroom),
               params: { student_pin: '2468', students: { 'kept-row' => row } },
               headers: turbo_headers
        end.not_to change(User.student, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(message, 'bulk_student_draft_kept-row')
        expect(response.body).to include(%(value="#{row[:student_number]}"))
        expect(ClassroomMembership.count).to eq(membership_count)
      end
    end

    it 'marks every duplicate student number in the submitted roster' do
      expect do
        post bulk_create_classroom_students_path(classroom),
             params: {
               student_pin: '2468',
               students: {
                 'first' => { student_number: '7', name: '첫 학생', gender: 'boy', avatar_key: 'boy01' },
                 'second' => { student_number: '7', name: '둘 학생', gender: 'girl', avatar_key: 'girl01' }
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body.scan('7번 출석번호가 명단 안에서 중복되었습니다.').size).to be >= 2
    end

    it 'rejects a number held by an active student but ignores inactive numbers' do
      active_student = create(:user, :student)
      create(:classroom_membership,
             user: active_student,
             classroom: classroom,
             role: 'student',
             status: 'active',
             student_number: 7)
      inactive_student = create(:user, :student)
      create(:classroom_membership,
             user: inactive_student,
             classroom: classroom,
             role: 'student',
             status: 'inactive',
             student_number: 8)

      post bulk_create_classroom_students_path(classroom),
           params: {
             student_pin: '2468',
             students: {
               '0' => { student_number: '7', name: '충돌 학생', gender: 'boy', avatar_key: 'boy01' }
             }
           },
           headers: turbo_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('7번 출석번호는 이미 사용 중입니다.')

      post bulk_create_classroom_students_path(classroom),
           params: {
             student_pin: '2468',
             students: {
               '0' => { student_number: '8', name: '허용 학생', gender: 'girl', avatar_key: 'girl01' }
             }
           }
      expect(User.find_by!(name: '허용 학생')).to be_present
    end

    it 'rolls back all rows when a later membership save fails' do
      calls = 0
      allow_any_instance_of(ClassroomMembership).to receive(:save!).and_wrap_original do |method, *args, **kwargs|
        calls += 1
        raise ActiveRecord::RecordInvalid.new(method.receiver) if calls == 2

        method.call(*args, **kwargs)
      end

      membership_count = ClassroomMembership.count
      expect do
        post bulk_create_classroom_students_path(classroom),
             params: { student_pin: '2468', students: draft_params },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ClassroomMembership.count).to eq(membership_count)
    end

    it 'rolls back all rows when a later user save fails' do
      calls = 0
      allow(User).to receive(:create!).and_wrap_original do |method, *args|
        calls += 1
        if calls == 2
          invalid_user = build(:user, :student)
          invalid_user.errors.add(:base, 'user failed')
          raise ActiveRecord::RecordInvalid.new(invalid_user)
        end

        method.call(*args)
      end

      membership_count = ClassroomMembership.count
      expect do
        post bulk_create_classroom_students_path(classroom),
             params: { student_pin: '2468', students: draft_params },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(ClassroomMembership.count).to eq(membership_count)
    end

    it 'turns a database student number race into a roster error and rolls back all rows' do
      allow_any_instance_of(ClassroomMembership).to receive(:save!)
        .and_raise(ActiveRecord::RecordNotUnique)

      membership_count = ClassroomMembership.count
      expect do
        post bulk_create_classroom_students_path(classroom),
             params: { student_pin: '2468', students: draft_params },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('1번 출석번호는 이미 사용 중입니다.')
      expect(response.body).to include('김학생', '이학생')
      expect(ClassroomMembership.count).to eq(membership_count)
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
      expect(response.body).to include('1번', '2번')
    end

    it 'rolls back when final submitted rows are invalid and keeps entered drafts visible' do
      expect do
        post bulk_create_classroom_students_path(classroom),
             params: {
               student_pin: '2468',
               students: {
                 '0' => { student_number: '1', name: '유지 학생', gender: 'boy', avatar_key: 'boy01' },
                 '2' => { student_number: 'abc', name: '', gender: 'girl', avatar_key: 'girl01' }
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('id="bulk-student-preview-form"')
      expect(response.body).to include('유지 학생')
      expect(response.body).to include('bulk_student_draft_0')
      expect(response.body).to include('bulk_student_draft_2')
      expect(response.body).not_to include('bulk_student_draft_1')
      expect(response.body).to include('이름을 입력해 주세요')
      expect(response.body).to include('value="abc"')
    end

    it 'does not create students when final submitted rows are empty' do
      expect do
        post bulk_create_classroom_students_path(classroom),
             params: { student_pin: '2468', students: {} },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('생성할 학생이 없습니다.')
    end

    it 'renders the submitted roster for a direct HTML validation error' do
      post bulk_create_classroom_students_path(classroom),
           params: {
             student_pin: '2468',
             students: {
               'html-row' => {
                 student_number: 'abc',
                 name: 'HTML 유지 학생',
                 gender: 'boy',
                 avatar_key: 'boy01'
               }
             }
           }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('id="bulk-student-preview-form"')
      expect(response.body).to include('HTML 유지 학생', 'value="abc"')
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

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('초기 PIN은 4자리 숫자여야 합니다.')
    end

    it 'rolls back when final create would exceed the student limit' do
      create_active_students(29, classroom: classroom)

      expect do
        post bulk_create_classroom_students_path(classroom),
             params: {
               student_pin: '2468',
               students: draft_params
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('최대 30명')
    end

    it 'allows final create when inactive memberships do not exceed the active student limit' do
      create_active_students(29, classroom: classroom)
      inactive_student = create(:user, :student, name: '기존 비활성 학생')
      create(:classroom_membership, user: inactive_student, classroom: classroom, role: 'student', status: 'inactive')

      expect do
        post bulk_create_classroom_students_path(classroom),
             params: {
               student_pin: '2468',
               students: {
                 '0' => { student_number: '1', name: '추가 학생', gender: 'boy', avatar_key: 'boy01' }
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
                 '0' => { student_number: '1', name: '잘못된 학생', gender: 'boy', avatar_key: 'teacherM01' }
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('썸네일을 확인해 주세요')
    end

    it 'rolls back when final avatar and gender do not match' do
      expect do
        post bulk_create_classroom_students_path(classroom),
             params: {
               student_pin: '2468',
               students: {
                 '0' => { student_number: '1', name: '성별 불일치', gender: 'boy', avatar_key: 'girl01' }
               }
             },
             headers: turbo_headers
      end.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('썸네일을 확인해 주세요')
    end

    it 'ignores arbitrary role email and password params on final create' do
      other_classroom = create(:classroom)
      post bulk_create_classroom_students_path(classroom),
           params: {
             student_pin: '2468',
             students: {
               '0' => {
                 student_number: '1',
                 name: '보안 학생',
                 gender: 'boy',
                 avatar_key: 'boy01',
                 role: 'admin',
                 status: 'inactive',
                 classroom_id: other_classroom.id,
                 email: 'ignored@example.com',
                 password: 'password123'
               }
             }
           }

      student = User.student.find_by!(name: '보안 학생')
      expect(student.role).to eq('student')
      expect(student.email).to be_nil
      expect(student.encrypted_password).to eq('')
      membership = classroom.classroom_memberships.find_by!(user: student)
      expect(membership).to be_active
      expect(membership.student_number).to eq(1)
      expect(other_classroom.classroom_memberships.where(user: student)).to be_empty
    end

    it 'rejects a teacher outside the classroom' do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      expect do
        post bulk_preview_classroom_students_path(classroom), params: { student_count: 2 }
      end.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end

    it 'allows an admin to preview drafts' do
      admin = create(:user, :admin)
      sign_out teacher
      sign_in admin

      post bulk_preview_classroom_students_path(classroom),
           params: { student_count: 1, student_pin: '2468' },
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
        post bulk_preview_classroom_students_path(classroom), params: { student_count: 1 }
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
      assignment_frame = document.at_css(%(turbo-frame[id="#{dom_id(student, :coupon_assignment)}"]))
      expect(assignment_frame['src']).to be_nil
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
      self_pin_links = document.css(
        %(a[href="#{edit_classroom_student_path(classroom, student)}"])
      ).select { |link| link.text.strip == I18n.t('students.show.actions.edit_pin') }
      expect(self_pin_links).to be_empty
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

      get classroom_student_path(classroom, student, open_coupon_assignment: '1')
      document = Nokogiri::HTML(response.body)
      expect(document.at_css(%(turbo-frame[id="#{dom_id(student, :coupon_assignment)}"]))).to be_nil
    end

    it 'automatically loads coupon assignment only when requested by an authorized teacher' do
      get classroom_student_path(classroom, student, open_coupon_assignment: '1')

      document = Nokogiri::HTML(response.body)
      assignment_frame = document.at_css(%(turbo-frame[id="#{dom_id(student, :coupon_assignment)}"]))
      expect(assignment_frame['src']).to eq(coupon_assignment_classroom_student_path(classroom, student))
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
      document = Nokogiri::HTML(response.body)
      self_pin_links = document.css(
        %(a[href="#{edit_classroom_student_path(classroom, student)}"])
      ).select { |link| link.text.strip == I18n.t('students.show.actions.edit_pin') }
      expect(response.body).not_to include('학생 정보·PIN 수정')
      expect(self_pin_links.one?).to eq(true)
      expect(response.body).not_to include('칭찬하기')
      expect(response.body).not_to include('쿠폰 지급')
      expect(response.body).not_to include('선택한 쿠폰 지급')
      expect(response.body).not_to include('교실로 돌아가기')
      expect(response.body).to include('한눈에 보기')
      expect(response.body).to include(classroom_student_messages_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
    end

    it 'shows one self PIN edit link on the student dashboard and activity pages' do
      sign_out teacher
      sign_in student

      [
        dashboard_classroom_student_path(classroom, student),
        activity_classroom_student_path(classroom, student)
      ].each do |path|
        get path

        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        self_pin_links = document.css(
          %(a[href="#{edit_classroom_student_path(classroom, student)}"])
        ).select { |link| link.text.strip == I18n.t('students.show.actions.edit_pin') }
        expect(self_pin_links.one?).to eq(true)
      end
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
      profile_card = document.at_css('[data-student-profile-card]')
      assignment_link = profile_card.at_css("a[data-turbo-frame='_top']")
      assignment_uri = URI.parse(assignment_link['href'])
      expect(assignment_link.text).to include('쿠폰 지급')
      expect(assignment_uri.path).to eq(classroom_student_path(classroom, student))
      expect(Rack::Utils.parse_nested_query(assignment_uri.query)).to include('open_coupon_assignment' => '1')
      expect(assignment_uri.fragment).to eq(dom_id(student, :coupon_assignment))
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
      create(:classroom_membership,
             user: student,
             classroom: classroom,
             role: 'student',
             student_number: 7)

      get edit_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="user[student_pin]"')
      expect(response.body).to include('name="classroom_membership[student_number]"')
      expect(response.body).to include('value="7"')
      expect(response.body).not_to include('name="user[email]"')
      expect(response.body).not_to include('name="user[password]"')
      expect(response.body).not_to include('name="user[password_confirmation]"')
    end

    it 'shows only read-only profile information and PIN fields to the active student' do
      student = create(:user, :student, student_pin: '1234', gender: 'boy', avatar_key: 'boy01')
      create(:classroom_membership,
             user: student,
             classroom: classroom,
             role: 'student',
             status: 'active',
             student_number: 7)
      sign_out teacher
      sign_in student

      get edit_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('PIN 수정', student.name, classroom.school.name, classroom.name)
      expect(response.body).to include('name="user[student_pin]"')
      expect(response.body).to include('name="user[student_pin_confirmation]"')
      expect(response.body).not_to include('name="user[name]"')
      expect(response.body).not_to include('name="user[gender]"')
      expect(response.body).not_to include('name="user[avatar_key]"')
      expect(response.body).not_to include('name="classroom_membership[student_number]"')
      student_number = Nokogiri::HTML(response.body).at_css('[data-testid="student-number"]')
      expect(student_number.text.squish).to include('출석번호', '7번')
      expect(response.body).not_to include('학생 정보 관리')
      expect(response.body).not_to include('운영 상태')
    end

    it 'shows an unassigned student number as read-only to a legacy student' do
      student = create(:user, :student, student_pin: '1234')
      create(:classroom_membership,
             user: student,
             classroom: classroom,
             role: 'student',
             status: 'active',
             student_number: nil)
      sign_out teacher
      sign_in student

      get edit_classroom_student_path(classroom, student)

      student_number = Nokogiri::HTML(response.body).at_css('[data-testid="student-number"]')
      expect(student_number.text.squish).to include('출석번호', '미지정')
      expect(response.body).not_to include('name="classroom_membership[student_number]"')
    end

    it 'rejects a student editing another student' do
      student = create(:user, :student, student_pin: '1234')
      other_student = create(:user, :student, student_pin: '5678')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student', status: 'active')
      create(:classroom_membership, user: other_student, classroom: classroom, role: 'student', status: 'active')
      sign_out teacher
      sign_in student

      get edit_classroom_student_path(classroom, other_student)

      expect(response).to redirect_to(root_path)
    end
  end

  describe 'PATCH /classrooms/:classroom_id/students/:id' do
    it 'lets an active student change only their own PIN' do
      student = create(:user, :student, student_pin: '1234', name: '기존 이름', gender: 'boy', avatar_key: 'boy01')
      membership = create(:classroom_membership,
                          user: student,
                          classroom: classroom,
                          role: 'student',
                          status: 'active',
                          student_number: 7)
      sign_out teacher
      sign_in student

      patch classroom_student_path(classroom, student), params: {
        user: {
          student_pin: '4321',
          student_pin_confirmation: '4321',
          name: '변조 이름',
          gender: 'girl',
          avatar_key: 'girl01',
          active: false,
          inactive_reason: '조작',
          role: 'admin',
          student_number: 8
        },
        student_number: 8,
        classroom_membership: { student_number: 9 }
      }

      expect(response).to redirect_to(classroom_student_path(classroom, student))
      student.reload
      expect(student.authenticate_student_pin('1234')).to be_falsey
      expect(student.authenticate_student_pin('4321')).to be_truthy
      expect(student.name).to eq('기존 이름')
      expect(student.gender).to eq('boy')
      expect(student.avatar_key).to eq('boy01')
      expect(student).to be_active
      expect(student).to be_student
      expect(membership.reload.student_number).to eq(7)
    end

    it 'rejects a student updating another student' do
      student = create(:user, :student, student_pin: '1234')
      other_student = create(:user, :student, student_pin: '5678')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student', status: 'active')
      create(:classroom_membership, user: other_student, classroom: classroom, role: 'student', status: 'active')
      sign_out teacher
      sign_in student

      patch classroom_student_path(classroom, other_student), params: {
        user: { student_pin: '4321', student_pin_confirmation: '4321' }
      }

      expect(response).to redirect_to(root_path)
      expect(other_student.reload.authenticate_student_pin('5678')).to be_truthy
    end

    it 'renders the student PIN screen for invalid or mismatched PIN values' do
      student = create(:user, :student, student_pin: '1234')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student', status: 'active')
      sign_out teacher
      sign_in student

      [
        ['', '', '새 PIN을 입력해 주세요.'],
        ['123', '123', '새 PIN은 4자리 숫자여야 합니다.'],
        ['12ab', '12ab', '새 PIN은 4자리 숫자여야 합니다.'],
        ['4321', '1111', '새 PIN 확인이 일치하지 않습니다.']
      ].each do |pin, confirmation, message|
        patch classroom_student_path(classroom, student), params: {
          user: { student_pin: pin, student_pin_confirmation: confirmation }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('PIN 수정', message)
        expect(response.body).not_to include('name="user[name]"')
        expect(response.body).not_to include('운영 상태')
        expect(student.reload.authenticate_student_pin('1234')).to be_truthy
      end
    end

    it 'keeps the existing admin student update flow and redirect' do
      student = create(:user, :student, name: '기존 이름', gender: 'boy', avatar_key: 'boy01')
      membership = create(:classroom_membership,
                          user: student,
                          classroom: classroom,
                          role: 'student')
      sign_out teacher
      sign_in create(:user, :admin)

      patch classroom_student_path(classroom, student), params: {
        classroom_membership: { student_number: 6 },
        user: { name: '관리자 수정', gender: 'boy', avatar_key: 'boy01' }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(student.reload.name).to eq('관리자 수정')
      expect(membership.reload.student_number).to eq(6)
    end

    it 'lets a teacher add, change, and clear a student number' do
      student = create(:user, :student, name: '번호 편집 학생')
      membership = create(:classroom_membership,
                          user: student,
                          classroom: classroom,
                          role: 'student',
                          student_number: nil)

      patch classroom_student_path(classroom, student), params: {
        classroom_membership: { student_number: 7 },
        user: { name: student.name }
      }
      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(membership.reload.student_number).to eq(7)

      patch classroom_student_path(classroom, student), params: {
        classroom_membership: { student_number: 9 },
        user: { name: student.name }
      }
      expect(membership.reload.student_number).to eq(9)

      patch classroom_student_path(classroom, student), params: {
        classroom_membership: { student_number: '' },
        user: { name: student.name }
      }
      expect(membership.reload.student_number).to be_nil
    end

    it 'rolls back user changes when an active student number is already used' do
      student = create(:user, :student, name: '기존 이름')
      membership = create(:classroom_membership,
                          user: student,
                          classroom: classroom,
                          role: 'student',
                          status: 'active',
                          student_number: 7)
      classmate = create(:user, :student)
      create(:classroom_membership,
             user: classmate,
             classroom: classroom,
             role: 'student',
             status: 'active',
             student_number: 8)

      patch classroom_student_path(classroom, student), params: {
        classroom_membership: { student_number: 8 },
        user: { name: '저장되면 안 되는 이름' }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('8번 출석번호는 이미 사용 중입니다.')
      expect(student.reload.name).to eq('기존 이름')
      expect(membership.reload.student_number).to eq(7)
    end

    it 'allows an inactive student to use a number held by an active student' do
      active_student = create(:user, :student)
      create(:classroom_membership,
             user: active_student,
             classroom: classroom,
             role: 'student',
             status: 'active',
             student_number: 7)
      inactive_student = create(:user, :student)
      inactive_membership = create(:classroom_membership,
                                   user: inactive_student,
                                   classroom: classroom,
                                   role: 'student',
                                   status: 'inactive',
                                   student_number: 9)

      patch classroom_student_path(classroom, inactive_student), params: {
        classroom_membership: { student_number: 7 },
        user: { name: inactive_student.name }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, inactive_student))
      expect(inactive_membership.reload.student_number).to eq(7)
    end

    it 'turns a student number database race into an edit error without saving user changes' do
      student = create(:user, :student, name: '경쟁 전 이름')
      membership = create(:classroom_membership,
                          user: student,
                          classroom: classroom,
                          role: 'student',
                          student_number: 7)
      allow_any_instance_of(ClassroomMembership).to receive(:save!)
        .and_raise(ActiveRecord::RecordNotUnique)

      patch classroom_student_path(classroom, student), params: {
        classroom_membership: { student_number: 8 },
        user: { name: '경쟁 후 이름' }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('8번 출석번호는 이미 사용 중입니다.')
      expect(student.reload.name).to eq('경쟁 전 이름')
      expect(membership.reload.student_number).to eq(7)
    end

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
      expect(student.encrypted_password).to eq('')
      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
    end

    it 'reassigns avatar_key when the form submits the previous avatar with a changed gender' do
      student = create(:user, :student, gender: 'boy', avatar_key: 'boy01')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          gender: 'girl',
          avatar_key: 'boy01'
        }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(student.reload.gender).to eq('girl')
      expect(student.avatar_key).to be_in(User::GIRL_AVATAR_KEYS)
    end

    it 'allows a matching avatar_key when gender is submitted together' do
      student = create(:user, :student, gender: 'boy', avatar_key: 'boy01')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          gender: 'girl',
          avatar_key: 'girl03'
        }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(student.reload.gender).to eq('girl')
      expect(student.avatar_key).to eq('girl03')
    end

    it 'rejects a non-current avatar_key that does not match the changed gender' do
      student = create(:user, :student, gender: 'boy', avatar_key: 'boy01')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          gender: 'girl',
          avatar_key: 'boy02'
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(student.reload.gender).to eq('boy')
      expect(student.avatar_key).to eq('boy01')
      expect(response.body).to include('성별에 맞는 아바타를 선택해 주세요.')
    end

    it 'rejects an opposite-gender avatar_key when gender is unchanged' do
      student = create(:user, :student, gender: 'girl', avatar_key: 'girl01')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          avatar_key: 'boy01'
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(student.reload.avatar_key).to eq('girl01')
    end

    it 'allows unrelated updates for legacy students without gender' do
      student = create(:user, :student, gender: nil)
      student.update_column(:avatar_key, 'boy01')
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: 'legacy renamed'
        }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(student.reload.name).to eq('legacy renamed')
      expect(student.avatar_key).to eq('boy01')
      expect(student.gender).to be_nil
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
      create_active_students(29, classroom: classroom)
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

    it 'rejects reactivation when the classroom already has 30 active students' do
      create_active_students(30, classroom: classroom)
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                 status: 'inactive')

      patch reactivate_classroom_student_path(classroom, student)

      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(flash[:alert]).to eq(I18n.t('students.reactivate.too_many', count: Classroom::MAX_ACTIVE_STUDENTS))
      expect(membership.reload).to be_inactive
    end

    it 'applies the active student limit to an admin reactivation' do
      admin = create(:user, :admin)
      create_active_students(30, classroom: classroom)
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: 'student',
                                                 status: 'inactive')
      sign_out teacher
      sign_in admin

      patch reactivate_classroom_student_path(classroom, student)

      expect(response).to redirect_to(classroom_members_path(classroom))
      expect(flash[:alert]).to eq(I18n.t('students.reactivate.too_many', count: Classroom::MAX_ACTIVE_STUDENTS))
      expect(membership.reload).to be_inactive
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
