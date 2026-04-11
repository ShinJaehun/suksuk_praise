require "rails_helper"

RSpec.describe ComplimentPolicy::Scope do
  describe "#resolve" do
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let(:other_student) { create(:user, :student) }
    let(:teacher_classroom) { create(:classroom) }
    let(:other_classroom) { create(:classroom) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: teacher_classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: teacher_classroom, role: "student") }
    let!(:other_student_membership) { create(:classroom_membership, user: other_student, classroom: other_classroom, role: "student") }
    let!(:visible_compliment) do
      create(:compliment, giver: teacher, receiver: student, classroom: teacher_classroom)
    end
    let!(:hidden_compliment) do
      create(:compliment, receiver: other_student, classroom: other_classroom)
    end

    it "returns all compliments for admin" do
      admin = create(:user, :admin)

      resolved = described_class.new(admin, Compliment.all).resolve

      expect(resolved).to contain_exactly(visible_compliment, hidden_compliment)
    end

    it "returns compliments only from the teacher's classrooms" do
      resolved = described_class.new(teacher, Compliment.all).resolve

      expect(resolved).to contain_exactly(visible_compliment)
    end

    it "returns only compliments received by the student" do
      teacher_classroom.classroom_memberships.find_or_create_by!(user: other_student) do |membership|
        membership.role = "student"
      end

      received_in_other_classroom = create(
        :compliment,
        giver: teacher,
        receiver: student,
        classroom: other_classroom
      )

      resolved = described_class.new(student, Compliment.all).resolve

      expect(resolved).to contain_exactly(visible_compliment, received_in_other_classroom)
    end

    it "returns no compliments for guest" do
      resolved = described_class.new(nil, Compliment.all).resolve

      expect(resolved).to be_empty
    end
  end
end
