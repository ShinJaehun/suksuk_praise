require "rails_helper"

RSpec.describe Classroom, type: :model do
  it "uses replies only messages by default" do
    classroom = described_class.create!(name: "기본 교실")

    expect(classroom.message_policy).to eq("replies_only")
    expect(classroom.student_messages_enabled?).to eq(true)
    expect(classroom.student_can_start_messages?).to eq(false)
  end

  it "supports disabled message policy" do
    classroom = described_class.create!(name: "비활성 교실", message_policy: "disabled")

    expect(classroom.messages_disabled?).to eq(true)
    expect(classroom.student_messages_enabled?).to eq(false)
    expect(classroom.student_can_start_messages?).to eq(false)
  end

  it "supports student initiated message policy" do
    classroom = described_class.create!(name: "학생 시작 교실", message_policy: "student_initiated")

    expect(classroom.student_messages_enabled?).to eq(true)
    expect(classroom.student_can_start_messages?).to eq(true)
  end

  it "generates a student login token" do
    classroom = described_class.create!(name: "토큰 교실")

    expect(classroom.student_login_token).to be_present
  end

  it "allows a name with 50 characters" do
    classroom = described_class.new(name: "가" * 50)

    expect(classroom).to be_valid
  end

  it "can belong to a school" do
    school = create(:school)
    classroom = build(:classroom, school: school)

    expect(classroom.school).to eq(school)
    expect(classroom).to be_valid
  end

  it "allows a blank school during the transition" do
    classroom = build(:classroom, school: nil)

    expect(classroom).to be_valid
  end

  it "rejects a school id that does not exist" do
    classroom = build(:classroom, school: nil, school_id: School.maximum(:id).to_i + 10_000)

    expect(classroom).not_to be_valid
    expect(classroom.errors[:school]).to be_present
  end

  it "allows grades from 1 to 6" do
    (1..6).each do |grade|
      classroom = build(:classroom, grade: grade)

      expect(classroom).to be_valid
    end
  end

  it "allows a blank grade during the transition" do
    classroom = build(:classroom, grade: nil)

    expect(classroom).to be_valid
  end

  it "rejects grades outside the elementary range" do
    [0, 7].each do |grade|
      classroom = build(:classroom, grade: grade)

      expect(classroom).not_to be_valid
    end
  end

  it "rejects a name with more than 50 characters" do
    classroom = described_class.new(name: "가" * 51)

    expect(classroom).not_to be_valid
  end

  it "returns only active student memberships from students" do
    classroom = create(:classroom)
    active_student = create(:user, :student)
    inactive_student = create(:user, :student)
    teacher = create(:user, :teacher)
    create(:classroom_membership, classroom: classroom, user: active_student, role: "student")
    create(:classroom_membership, classroom: classroom, user: inactive_student, role: "student", status: "inactive")
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")

    expect(classroom.students).to contain_exactly(active_student)
  end
end
