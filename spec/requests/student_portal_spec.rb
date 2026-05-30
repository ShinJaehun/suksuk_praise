require 'rails_helper'

RSpec.describe 'Student portal flow', type: :request do
  describe 'student landing and access boundaries' do
    let(:student) { create(:user, :student, password: 'password123') }
    let(:teacher) { create(:user, :teacher) }
    let(:classroom) { create(:classroom) }

    before do
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      create(:classroom_membership, user: teacher, classroom: classroom, role: 'teacher')
    end

    it 'blocks a student from signing in through Devise' do
      post user_session_path, params: {
        user: {
          email: student.email,
          password: 'password123'
        }
      }

      expect(response).to redirect_to(new_student_session_path)
    end

    it 'redirects a signed-in student away from classrooms index' do
      sign_in student

      get classrooms_path

      expect(response).to redirect_to(user_path(student))
    end

    it 'redirects a signed-in student away from classrooms show' do
      sign_in student

      get classroom_path(classroom)

      expect(response).to redirect_to(user_path(student))
    end

    it 'redirects a student self page to the classroom-scoped page' do
      sign_in student

      get user_path(student)

      expect(response).to redirect_to(classroom_student_path(classroom, student))
    end

    it 'redirects a teacher from non-nested student show to the classroom-scoped page' do
      sign_in teacher

      get user_path(student)

      expect(response).to redirect_to(classroom_student_path(classroom, student))
    end

    it 'redirects an admin from their own user show to classrooms index' do
      admin = create(:user, :admin)
      sign_in admin

      get user_path(admin)

      expect(response).to redirect_to(classrooms_path)
    end

    it 'redirects a teacher from their own user show to their single assigned classroom' do
      sign_in teacher

      get user_path(teacher)

      expect(response).to redirect_to(classroom_path(classroom))
    end

    it 'redirects a teacher from their own user show to classrooms index when they have multiple assigned classrooms' do
      other_classroom = create(:classroom)
      create(:classroom_membership, user: teacher, classroom: other_classroom, role: 'teacher')
      sign_in teacher

      get user_path(teacher)

      expect(response).to redirect_to(classrooms_path)
    end

    it 'redirects an admin from teacher user show to classrooms index' do
      admin = create(:user, :admin)
      sign_in admin

      get user_path(teacher)

      expect(response).to redirect_to(classrooms_path)
    end

    it 'allows a teacher to view the classroom-scoped student page' do
      sign_in teacher

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('계정 관리')
      expect(response.body).to include('교실로 돌아가기')
      expect(response.body).not_to include("#{classroom.name} 교실로 돌아가기")
      expect(response.body).to include(classroom.name)
      expect(response.body).not_to include('내 마이페이지')
      expect(response.body).not_to include('내 소속 교실')
    end

    it "blocks a student from viewing another student's classroom-scoped page" do
      other_student = create(:user, :student)
      create(:classroom_membership, user: other_student, classroom: classroom, role: 'student')
      sign_in student

      get classroom_student_path(classroom, other_student)

      expect(response).to redirect_to(root_path)
    end

    it 'does not expose avatar management controls on the student self page' do
      sign_in student

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('교실로 돌아가기')
      expect(response.body).not_to include('아바타 변경')
      expect(response.body).not_to include('name="user[avatar_key]"')
    end
  end

  describe 'student account deletion boundary' do
    let(:student) { create(:user, :student) }
    let(:teacher) { create(:user, :teacher) }
    let(:classroom) { create(:classroom) }

    before do
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      create(:classroom_membership, user: teacher, classroom: classroom, role: 'teacher')
    end

    it 'rejects self-service student deletion' do
      sign_in student

      expect do
        delete classroom_student_path(classroom, student)
      end.not_to change(User, :count)

      expect(response).to redirect_to(root_path)
    end

    it 'allows a classroom teacher to delete a student from the managed page' do
      sign_in teacher

      expect do
        delete classroom_student_path(classroom, student)
      end.to change(User, :count).by(-1)

      expect(response).to redirect_to(classroom_path(classroom))
    end
  end

  describe 'managed student account page' do
    let(:student) { create(:user, :student, password: 'password123') }
    let(:teacher) { create(:user, :teacher) }
    let(:classroom) { create(:classroom) }

    before do
      create(:classroom_membership, user: student, classroom: classroom, role: 'student')
      create(:classroom_membership, user: teacher, classroom: classroom, role: 'teacher')
    end

    it 'allows a classroom teacher to open the managed account page' do
      sign_in teacher

      get edit_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('기본 정보')
      expect(response.body).to include('아바타 선택')
      expect(response.body).to include('아바타 변경')
      expect(response.body).to include('name="user[avatar_key]"')
      expect(response.body).to include('boy01')
      expect(response.body).to include('girl01')
      expect(response.body).not_to include('value="teacherM01"')
      expect(response.body).not_to include('value="teacherF01"')
      expect(response.body).not_to include('value="admin"')
      expect(response.body).to include('PIN 설정')
      expect(response.body).to include('계정 삭제')
      expect(response.body).not_to include('비밀번호 재설정')
      expect(response.body).not_to include('name="user[password]"')
      expect(response.body).not_to include('name="user[password_confirmation]"')
    end

    it 'allows a classroom teacher to update student name and email' do
      sign_in teacher

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: '새 이름',
          email: 'student-updated@example.com'
        }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(student.reload.name).to eq('새 이름')
      expect(student.email).to eq('student-updated@example.com')
    end

    it 'allows a classroom teacher to update student avatar_key' do
      sign_in teacher

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          email: student.email,
          gender: 'girl',
          avatar_key: 'girl03'
        }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(student.reload.avatar_key).to eq('girl03')
    end

    it 'allows an admin to update student avatar_key' do
      admin = create(:user, :admin)
      sign_in admin

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          email: student.email,
          gender: 'boy',
          avatar_key: 'boy04'
        }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(student.reload.avatar_key).to eq('boy04')
    end

    it 'rejects invalid avatar_key values' do
      original_avatar_key = student.avatar_key
      sign_in teacher

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          email: student.email,
          avatar_key: 'unknown'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(student.reload.avatar_key).to eq(original_avatar_key)
    end

    it 'rejects teacher avatar_key values' do
      original_avatar_key = student.avatar_key
      sign_in teacher

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          email: student.email,
          avatar_key: 'teacherM01'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(student.reload.avatar_key).to eq(original_avatar_key)
    end

    it 'allows a classroom teacher to reset student password' do
      sign_in teacher

      patch reset_password_classroom_student_path(classroom, student), params: {
        user: {
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
      }

      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
      expect(student.reload.valid_password?('newpassword123')).to eq(true)
    end
  end
end
