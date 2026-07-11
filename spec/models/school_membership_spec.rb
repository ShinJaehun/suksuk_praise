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

  it "allows different teachers to belong to the same school" do
    school = create(:school)

    expect(create(:school_membership, school: school, user: create(:user, :teacher))).to be_persisted
    expect(create(:school_membership, school: school, user: create(:user, :teacher))).to be_persisted
  end

  it "rejects a second school membership for the same teacher" do
    teacher = create(:user, :teacher)
    create(:school_membership, user: teacher)

    duplicate = build(:school_membership, user: teacher)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end

  it "rejects student and admin users" do
    [create(:user, :student), create(:user, :admin)].each do |user|
      membership = build(:school_membership, user: user)

      expect(membership).not_to be_valid
      expect(membership.errors[:user]).to be_present
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
