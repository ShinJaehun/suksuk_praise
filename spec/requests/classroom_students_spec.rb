require "rails_helper"

RSpec.describe "Classroom students", type: :request do
  let(:teacher) { create(:user, :teacher) }
  let(:classroom) { create(:classroom) }

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
