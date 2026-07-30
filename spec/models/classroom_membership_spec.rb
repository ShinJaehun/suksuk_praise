require "rails_helper"

RSpec.describe ClassroomMembership, type: :model do
  let(:student) { create(:user, :student) }
  let(:first_classroom) { create(:classroom) }
  let(:second_classroom) { create(:classroom) }

  def insert_membership!(attrs)
    now = Time.current

    described_class.insert!(
      {
        user_id: create(:user, :student).id,
        classroom_id: first_classroom.id,
        role: "student",
        status: "active",
        student_number: 1,
        created_at: now,
        updated_at: now
      }.merge(attrs)
    )
  end

  describe "student number" do
    it "allows nil and positive integer numbers" do
      expect(build(:classroom_membership, student_number: nil)).to be_valid
      expect(build(:classroom_membership, student_number: 1)).to be_valid
    end

    it "rejects zero, negative, decimal, and non-numeric numbers" do
      [0, -1, 1.5, "number"].each do |value|
        membership = build(:classroom_membership, student_number: value)

        expect(membership).not_to be_valid
        expect(membership.errors[:student_number]).to be_present
      end
    end

    it "rejects duplicate numbered active students in the same classroom" do
      create(:classroom_membership, classroom: first_classroom, user: student,
                                    student_number: 7, status: "active")
      duplicate = build(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student),
        student_number: 7,
        status: "active"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:student_number]).to be_present
    end

    it "enforces duplicate active student numbers at the database level" do
      insert_membership!(student_number: 7)

      expect {
        insert_membership!(student_number: 7)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same student number in different classrooms" do
      create(:classroom_membership, classroom: first_classroom, user: student, student_number: 7)
      membership = build(
        :classroom_membership,
        classroom: second_classroom,
        user: create(:user, :student),
        student_number: 7
      )

      expect(membership).to be_valid
    end

    it "allows an inactive student and an active student to share a number" do
      create(:classroom_membership, classroom: first_classroom, user: student,
                                    student_number: 7, status: "inactive")
      membership = build(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student),
        student_number: 7,
        status: "active"
      )

      expect(membership).to be_valid
    end

    it "does not apply active student number uniqueness to teacher memberships" do
      create(:classroom_membership, classroom: first_classroom, user: student,
                                    student_number: 7, status: "active")
      teacher_membership = build(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :teacher),
        role: "teacher",
        student_number: 7,
        status: "active"
      )

      expect(teacher_membership).to be_valid
    end

    it "rejects activating an inactive student when its number is already active" do
      create(:classroom_membership, classroom: first_classroom, user: student,
                                    student_number: 7, status: "active")
      membership = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student),
        student_number: 7,
        status: "inactive"
      )

      expect(membership.update(status: "active")).to eq(false)
      expect(membership.errors[:student_number]).to be_present
      expect(membership.reload).to be_inactive
    end

    it "rejects changing a teacher membership to student when its number is already active" do
      create(:classroom_membership, classroom: first_classroom, user: student,
                                    student_number: 7, status: "active")
      membership = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :teacher),
        role: "teacher",
        student_number: 7
      )

      expect(membership.update(role: "student")).to eq(false)
      expect(membership.errors[:student_number]).to be_present
      expect(membership.reload).to be_teacher
    end
  end

  describe ".in_roster_order" do
    it "orders numbered memberships first and unnumbered memberships by name and id" do
      number_five = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student, name: "다섯"),
        student_number: 5
      )
      unnumbered_second = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student, name: "Unnumbered B"),
        student_number: nil
      )
      number_one = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student, name: "하나"),
        student_number: 1
      )
      number_two = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student, name: "둘"),
        student_number: 2
      )
      unnumbered_first = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student, name: "Unnumbered A"),
        student_number: nil
      )

      ordered = described_class
        .where(classroom: first_classroom)
        .in_roster_order

      expect(ordered).to eq([
        number_one,
        number_two,
        number_five,
        unnumbered_first,
        unnumbered_second
      ])
    end

    it "keeps allowed duplicate numbers stable for inactive students and teachers" do
      inactive = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :student, name: "같은 이름"),
        student_number: 7,
        status: "inactive"
      )
      teacher = create(
        :classroom_membership,
        classroom: first_classroom,
        user: create(:user, :teacher, name: "같은 이름"),
        role: "teacher",
        student_number: 7
      )

      ordered_ids = described_class
        .where(id: [inactive.id, teacher.id])
        .in_roster_order
        .pluck(:id)

      expect(ordered_ids).to eq(
        [inactive, teacher].sort_by { |membership| [membership.user_id, membership.id] }.map(&:id)
      )
    end

    it "uses user and membership ids as stable ties for unnumbered students with the same name" do
      first_user = create(:user, :student, name: "Same Name")
      second_user = create(:user, :student, name: "Same Name")
      second_membership = create(
        :classroom_membership,
        classroom: first_classroom,
        user: second_user,
        student_number: nil
      )
      first_membership = create(
        :classroom_membership,
        classroom: first_classroom,
        user: first_user,
        student_number: nil
      )

      ordered_ids = described_class
        .where(id: [second_membership.id, first_membership.id])
        .in_roster_order
        .pluck(:id)

      expect(ordered_ids).to eq([first_membership.id, second_membership.id])
    end
  end

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

  it "rejects an inactive teacher membership" do
    teacher = create(:user, :teacher)
    membership = build(
      :classroom_membership,
      user: teacher,
      classroom: first_classroom,
      role: "teacher",
      status: "inactive"
    )

    expect(membership).not_to be_valid
    expect(membership.errors.added?(:status, :teacher_must_be_active)).to eq(true)
  end

  it "allows both active and inactive student memberships" do
    active_membership = build(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")
    inactive_membership = build(:classroom_membership, user: student, classroom: second_classroom, role: "student", status: "inactive")

    expect(active_membership).to be_valid
    expect(inactive_membership).to be_valid
  end

  it "allows different students to each have an active membership" do
    other_student = create(:user, :student)
    first_membership = create(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")
    second_membership = create(:classroom_membership, user: other_student, classroom: second_classroom, role: "student", status: "active")

    expect(first_membership).to be_persisted
    expect(second_membership).to be_persisted
  end
end
