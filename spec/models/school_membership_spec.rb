require "rails_helper"

RSpec.describe SchoolMembership, type: :model do
  it "is valid for a teacher and exposes its associations" do
    school = create(:school)
    teacher = create(:user, :teacher)
    membership = build(:school_membership, school: school, user: teacher)

    expect(membership).to be_valid
    expect(membership.school).to eq(school)
    expect(membership.user).to eq(teacher)
  end

  it "defaults to the member role" do
    membership = described_class.new

    expect(membership).to be_member
  end

  it "allows a teacher to be a manager" do
    membership = create(:school_membership, :manager)

    expect(membership).to be_manager
    expect(membership.user).to be_teacher
  end

  it "allows different teachers to belong to the same school" do
    school = create(:school)

    expect(create(:school_membership, school: school, user: create(:user, :teacher))).to be_persisted
    expect(create(:school_membership, school: school, user: create(:user, :teacher))).to be_persisted
  end

  it "allows multiple managers to belong to the same school" do
    school = create(:school)

    first_manager = create(:school_membership, :manager, school: school)
    second_manager = create(:school_membership, :manager, school: school)

    expect(first_manager).to be_manager
    expect(second_manager).to be_manager
  end

  it "rejects a second school membership for the same teacher" do
    teacher = create(:user, :teacher)
    create(:school_membership, user: teacher)

    duplicate = build(:school_membership, user: teacher)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end

  it "rejects student and admin users for both school roles" do
    %i[student admin].product(%i[member manager]).each do |user_role, school_role|
      membership = build(
        :school_membership,
        user: create(:user, user_role),
        role: school_role
      )

      expect(membership).not_to be_valid
      expect(membership.errors[:user]).to include("는 선생님 계정이어야 합니다.")
    end
  end

  it "is deleted with its user" do
    membership = create(:school_membership)

    expect { membership.user.destroy! }.to change(described_class, :count).by(-1)
  end

  it "prevents its school from being deleted" do
    membership = create(:school_membership)

    expect { membership.school.destroy }.not_to change(School, :count)
    expect(membership.school).not_to be_destroyed
  end

  it "allows a teacher to exist without a school" do
    teacher = create(:user, :teacher)

    expect(teacher.school_membership).to be_nil
    expect(teacher.school).to be_nil
  end
end
