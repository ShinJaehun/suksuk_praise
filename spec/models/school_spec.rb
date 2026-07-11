require "rails_helper"

RSpec.describe School, type: :model do
  it "is valid with a name" do
    school = described_class.new(name: "새싹초등학교")

    expect(school).to be_valid
  end

  it "rejects a blank name" do
    school = described_class.new(name: "")

    expect(school).not_to be_valid
  end

  it "can have many classrooms" do
    school = create(:school)
    first_classroom = create(:classroom, school: school)
    second_classroom = create(:classroom, school: school)

    expect(school.classrooms).to contain_exactly(first_classroom, second_classroom)
  end

  it "does not cascade delete classrooms" do
    school = create(:school)
    create(:classroom, school: school)

    expect { school.destroy }.not_to change(Classroom, :count)
    expect(school).not_to be_destroyed
  end

  it "exposes teachers through school memberships" do
    school = create(:school)
    teacher = create(:user, :teacher)
    create(:school_membership, school: school, user: teacher)

    expect(school.teachers).to contain_exactly(teacher)
  end
end
