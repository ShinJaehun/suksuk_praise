require "rails_helper"

RSpec.describe "Classroom students", type: :request do
  let(:teacher) { create(:user, :teacher) }
  let(:classroom) { create(:classroom) }
  let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }

  before do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher
  end

  describe "POST /classrooms/:classroom_id/students" do
    it "assigns a gendered avatar_key without reusing available keys in the classroom" do
      User::BOY_AVATAR_KEYS.first(22).each do |avatar_key|
        student = create(:user, :student, gender: "boy", avatar_key: avatar_key)
        create(:classroom_membership, user: student, classroom: classroom, role: "student")
      end

      post classroom_students_path(classroom), params: {
        user: {
          name: "새 학생",
          email: "new-student@example.com",
          password: "password123",
          gender: "boy"
        }
      }

      student = User.find_by!(email: "new-student@example.com")
      expect(student.gender).to eq("boy")
      expect(student.avatar_key).to eq("boy23")
      expect(response).to redirect_to(classroom_path(classroom))
    end

    it "creates a student and classroom membership with turbo stream" do
      expect {
        post classroom_students_path(classroom),
          params: {
            user: {
              name: "터보 학생",
              email: "turbo-student@example.com",
              password: "password123",
              gender: "girl"
            }
          },
          headers: turbo_headers
      }.to change(User.student, :count).by(1)
        .and change(ClassroomMembership, :count).by(1)

      student = User.find_by!(email: "turbo-student@example.com")
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(classroom.classroom_memberships.exists?(user: student, role: "student")).to eq(true)
    end

    it "returns 422 with turbo stream when the student is invalid" do
      expect {
        post classroom_students_path(classroom),
          params: {
            user: {
              name: "",
              email: "invalid-student@example.com",
              password: "password123",
              gender: "boy"
            }
          },
          headers: turbo_headers
      }.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "rejects a teacher outside the classroom" do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      expect {
        post classroom_students_path(classroom), params: {
          user: {
            name: "외부 생성",
            email: "outside-create@example.com",
            password: "password123",
            gender: "boy"
          }
        }
      }.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end

    it "rejects a student" do
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      sign_out teacher
      sign_in student

      expect {
        post classroom_students_path(classroom), params: {
          user: {
            name: "학생 생성",
            email: "student-create@example.com",
            password: "password123",
            gender: "girl"
          }
        }
      }.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /classrooms/:classroom_id/students/bulk_create" do
    it "creates students from boy_count and girl_count" do
      post bulk_create_classroom_students_path(classroom), params: {
        boy_count: 2,
        girl_count: 1
      }

      students = classroom.students.order(:created_at).last(3)
      expect(students.map(&:gender)).to contain_exactly("boy", "boy", "girl")
      expect(students.map(&:avatar_key)).to all(be_present)
      expect(response).to redirect_to(classroom_path(classroom))
    end

    it "returns a turbo stream alert without creating students when the requested count exceeds 30" do
      expect {
        post bulk_create_classroom_students_path(classroom),
          params: {
            boy_count: 30,
            girl_count: 30
          },
          headers: turbo_headers
      }.not_to change(User.student, :count)

      expect(response).not_to be_redirect
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="modal"')
      expect(response.body).to include("한 번에 자동 생성할 수 있는 학생은 최대 30명입니다.")
    end

    it "creates students and updates the students list and modal with turbo stream" do
      expect {
        post bulk_create_classroom_students_path(classroom),
          params: {
            boy_count: 1,
            girl_count: 1
          },
          headers: turbo_headers
      }.to change(User.student, :count).by(2)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(target="students_list_#{classroom.id}"))
      expect(response.body).to include('target="modal"')
    end

    it "rejects a teacher outside the classroom" do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      expect {
        post bulk_create_classroom_students_path(classroom), params: {
          boy_count: 1,
          girl_count: 1
        }
      }.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /classrooms/:classroom_id/students/:id" do
    it "reassigns avatar_key when gender changes and no custom avatar is attached" do
      student = create(:user, :student, gender: "boy", avatar_key: "boy01")
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      User::GIRL_AVATAR_KEYS.first(16).each do |avatar_key|
        classmate = create(:user, :student, gender: "girl", avatar_key: avatar_key)
        create(:classroom_membership, user: classmate, classroom: classroom, role: "student")
      end

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          email: student.email,
          gender: "girl"
        }
      }

      expect(student.reload.gender).to eq("girl")
      expect(student.avatar_key).to eq("girl17")
      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
    end
  end
end
