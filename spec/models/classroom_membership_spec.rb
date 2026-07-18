require "rails_helper"

RSpec.describe ClassroomMembership, type: :model do
  let(:student) { create(:user, :student) }
  let(:first_classroom) { create(:classroom) }
  let(:second_classroom) { create(:classroom) }

  it "allows a student to have one active classroom membership" do
    membership = create(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")

    expect(membership).to be_persisted
  end

  it "rejects a second active classroom membership for the same student" do
    create(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")
    membership = build(:classroom_membership, user: student, classroom: second_classroom, role: "student", status: "active")

    expect(membership).not_to be_valid
    expect(membership.errors.added?(:base, :active_student_membership_taken)).to eq(true)
  end

  it "allows one active and multiple inactive memberships for a student" do
    create(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")
    inactive_memberships = create_list(:classroom, 2).map do |classroom|
      create(:classroom_membership, user: student, classroom: classroom, role: "student", status: "inactive")
    end

    expect(inactive_memberships).to all(be_persisted)
  end

  it "allows multiple inactive memberships for a student" do
    memberships = [first_classroom, second_classroom].map do |classroom|
      create(:classroom_membership, user: student, classroom: classroom, role: "student", status: "inactive")
    end

    expect(memberships).to all(be_persisted)
  end

  it "rejects activating an inactive membership while another active membership exists" do
    create(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")
    membership = create(:classroom_membership, user: student, classroom: second_classroom, role: "student", status: "inactive")

    expect(membership.update(status: "active")).to eq(false)
    expect(membership.errors.added?(:base, :active_student_membership_taken)).to eq(true)
    expect(membership.reload).to be_inactive
  end

  it "allows changing the current active membership to inactive" do
    membership = create(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")

    expect(membership.update(status: "inactive")).to eq(true)
    expect(membership.reload).to be_inactive
  end

  it "allows a teacher to have active memberships in multiple classrooms" do
    teacher = create(:user, :teacher)

    memberships = [first_classroom, second_classroom].map do |classroom|
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher", status: "active")
    end

    expect(memberships).to all(be_persisted)
  end

  it "allows different students to each have an active membership" do
    other_student = create(:user, :student)
    first_membership = create(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")
    second_membership = create(:classroom_membership, user: other_student, classroom: second_classroom, role: "student", status: "active")

    expect(first_membership).to be_persisted
    expect(second_membership).to be_persisted
  end
end
