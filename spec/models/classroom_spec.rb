require "rails_helper"

RSpec.describe Classroom, type: :model do
  it "uses replies only messages by default" do
    classroom = create(:classroom, name: "기본 교실")

    expect(classroom.message_policy).to eq("replies_only")
    expect(classroom.student_messages_enabled?).to eq(true)
    expect(classroom.student_can_start_messages?).to eq(false)
  end

  it "supports disabled message policy" do
    classroom = create(:classroom, name: "비활성 교실", message_policy: "disabled")

    expect(classroom.messages_disabled?).to eq(true)
    expect(classroom.student_messages_enabled?).to eq(false)
    expect(classroom.student_can_start_messages?).to eq(false)
  end

  it "supports student initiated message policy" do
    classroom = create(:classroom, name: "학생 시작 교실", message_policy: "student_initiated")

    expect(classroom.student_messages_enabled?).to eq(true)
    expect(classroom.student_can_start_messages?).to eq(true)
  end

  it "generates a student login token" do
    classroom = create(:classroom, name: "토큰 교실")

    expect(classroom.student_login_token).to be_present
  end

  it "allows a name with 50 characters" do
    classroom = build(:classroom, name: "가" * 50)

    expect(classroom).to be_valid
  end

  it "can belong to a school" do
    school = create(:school)
    classroom = build(:classroom, school: school)

    expect(classroom.school).to eq(school)
    expect(classroom).to be_valid
  end

  it "rejects a blank school" do
    classroom = build(:classroom, school: nil)

    expect(classroom).not_to be_valid
    expect(classroom.errors[:school]).to be_present
  end

  it "rejects a school id that does not exist" do
    classroom = build(:classroom, school: nil, school_id: School.maximum(:id).to_i + 10_000)

    expect(classroom).not_to be_valid
    expect(classroom.errors[:school]).to be_present
  end

  it "allows grades 1 and 6" do
    [1, 6].each do |grade|
      classroom = build(:classroom, grade: grade)

      expect(classroom).to be_valid
    end
  end

  it "rejects a blank grade" do
    classroom = build(:classroom, grade: nil)

    expect(classroom).not_to be_valid
    expect(classroom.errors[:grade]).to be_present
  end

  it "rejects grades outside the elementary range" do
    [0, 7].each do |grade|
      classroom = build(:classroom, grade: grade)

      expect(classroom).not_to be_valid
    end
  end

  it "rejects a name with more than 50 characters" do
    classroom = build(:classroom, name: "가" * 51)

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

  describe "hard delete safety" do
    it "allows deletion when only teacher memberships exist" do
      classroom = create(:classroom)
      teacher = create(:user, :teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")

      expect(classroom.destroy).to be_truthy
      expect(Classroom.exists?(classroom.id)).to eq(false)
      expect(User.exists?(teacher.id)).to eq(true)
      expect(ClassroomMembership.where(classroom_id: classroom.id)).to be_empty
    end

    it "rejects deletion when an active student membership exists" do
      classroom = create(:classroom)
      membership = create(:classroom_membership, classroom: classroom, role: "student", status: "active")

      expect(classroom.destroy).to eq(false)
      expect(Classroom.exists?(classroom.id)).to eq(true)
      expect(ClassroomMembership.exists?(membership.id)).to eq(true)
      expect(classroom.errors.details[:base]).to include(error: :students_or_history_present)
    end

    it "rejects deletion when an inactive student membership exists" do
      classroom = create(:classroom)
      membership = create(:classroom_membership, classroom: classroom, role: "student", status: "inactive")

      expect(classroom.destroy).to eq(false)
      expect(Classroom.exists?(classroom.id)).to eq(true)
      expect(ClassroomMembership.exists?(membership.id)).to eq(true)
    end

    it "preserves the classroom and compliment when a compliment exists" do
      classroom = create(:classroom)
      compliment = create(:compliment, classroom: classroom)

      expect(classroom.destroy).to eq(false)
      expect(Classroom.exists?(classroom.id)).to eq(true)
      expect(Compliment.exists?(compliment.id)).to eq(true)
    end

    it "preserves the classroom and coupon when an issued coupon exists" do
      classroom = create(:classroom)
      coupon_owner = create(:user, :teacher)
      create(:classroom_membership, classroom: classroom, user: coupon_owner, role: "teacher")
      coupon = create(:user_coupon, classroom: classroom, user: coupon_owner)

      expect(classroom.destroy).to eq(false)
      expect(Classroom.exists?(classroom.id)).to eq(true)
      expect(UserCoupon.exists?(coupon.id)).to eq(true)
      expect(ClassroomMembership.where(classroom: classroom).count).to eq(1)
    end

    it "preserves the classroom and message when a student message exists" do
      classroom = create(:classroom)
      teacher = create(:user, :teacher)
      student = create(:user, :student)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      create(:classroom_membership, classroom: classroom, user: student, role: "student")
      message = create(:user_message, classroom: classroom, sender: teacher, recipient: student)
      membership_count = classroom.classroom_memberships.count

      expect(classroom.destroy).to eq(false)
      expect(Classroom.exists?(classroom.id)).to eq(true)
      expect(UserMessage.exists?(message.id)).to eq(true)
      expect(classroom.classroom_memberships.count).to eq(membership_count)
    end

    it "preserves the classroom and coupon event when a coupon event exists" do
      event = create(:coupon_event)
      classroom = event.classroom
      membership_count = classroom.classroom_memberships.count

      expect(classroom.destroy).to eq(false)
      expect(Classroom.exists?(classroom.id)).to eq(true)
      expect(CouponEvent.exists?(event.id)).to eq(true)
      expect(UserCoupon.exists?(event.user_coupon_id)).to eq(true)
      expect(classroom.classroom_memberships.count).to eq(membership_count)
    end
  end
end
