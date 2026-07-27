require "rails_helper"

RSpec.describe StudentActivityNotePolicy do
  let(:classroom) { create(:classroom) }
  let(:author) { create(:user, :teacher) }
  let(:other_teacher) { create(:user, :teacher) }
  let(:student) { create(:user, :student) }
  let(:note) { create(:student_activity_note, source: create(:compliment, classroom: classroom), author: author) }

  before do
    create(:classroom_membership, classroom: classroom, user: author, role: "teacher")
    create(:classroom_membership, classroom: classroom, user: other_teacher, role: "teacher")
  end

  it "allows an admin to create, update, and destroy notes" do
    policy = described_class.new(create(:user, :admin), note)

    expect(policy.create?).to eq(true)
    expect(policy.update?).to eq(true)
    expect(policy.destroy?).to eq(true)
  end

  it "allows a classroom teacher to create a note" do
    expect(described_class.new(author, note).create?).to eq(true)
  end

  it "rejects creation by an outside teacher, student, or unassigned school manager" do
    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: classroom.school, user: manager)

    expect(described_class.new(create(:user, :teacher), note).create?).to eq(false)
    expect(described_class.new(student, note).create?).to eq(false)
    expect(described_class.new(manager, note).create?).to eq(false)
  end

  it "allows only the current classroom teacher who authored the note to update or destroy it" do
    author_policy = described_class.new(author, note)
    other_policy = described_class.new(other_teacher, note)

    expect(author_policy.update?).to eq(true)
    expect(author_policy.destroy?).to eq(true)
    expect(other_policy.update?).to eq(false)
    expect(other_policy.destroy?).to eq(false)
  end

  it "rejects an outside teacher and a former author" do
    outside_policy = described_class.new(create(:user, :teacher), note)
    author.classroom_memberships.find_by!(classroom: classroom, role: "teacher").destroy!
    former_policy = described_class.new(author, note)

    expect(outside_policy.update?).to eq(false)
    expect(outside_policy.destroy?).to eq(false)
    expect(former_policy.update?).to eq(false)
    expect(former_policy.destroy?).to eq(false)
  end
end
