require "rails_helper"

RSpec.describe User, type: :model do
  describe ".avatar_keys_for" do
    it "returns boy avatar keys" do
      expect(described_class.avatar_keys_for("boy")).to include("boy01", "boy23")
    end

    it "returns girl avatar keys" do
      expect(described_class.avatar_keys_for("girl")).to include("girl01", "girl17")
    end

    it "returns male teacher avatar keys" do
      expect(described_class.avatar_keys_for("male")).to eq(%w[teacherM01 teacherM02 teacherM03 teacherM04 teacherM05 teacherM06 teacherM07 teacherM08])
    end

    it "returns female teacher avatar keys" do
      expect(described_class.avatar_keys_for("female")).to eq(%w[teacherF01 teacherF02 teacherF03 teacherF04 teacherF05 teacherF06])
    end

    it "returns admin avatar keys" do
      expect(described_class.avatar_keys_for("admin")).to eq(["admin"])
    end

    it "returns an empty array for unknown gender" do
      expect(described_class.avatar_keys_for("unknown")).to eq([])
    end
  end

  describe ".avatar_keys_for_role" do
    it "returns only student avatars for students" do
      expect(described_class.avatar_keys_for_role("student")).to eq(
        described_class::BOY_AVATAR_KEYS + described_class::GIRL_AVATAR_KEYS
      )
    end

    it "returns only teacher avatars for teachers" do
      expect(described_class.avatar_keys_for_role("teacher")).to eq(
        described_class::TEACHER_MALE_AVATAR_KEYS + described_class::TEACHER_FEMALE_AVATAR_KEYS
      )
    end

    it "returns admin and teacher avatars for admins" do
      expect(described_class.avatar_keys_for_role("admin")).to eq(
        described_class::ADMIN_AVATAR_KEYS + described_class::TEACHER_AVATAR_KEYS
      )
    end
  end

  it "validates gender values" do
    user = build(:user, gender: "other")

    expect(user).not_to be_valid
  end

  it "validates avatar_key values" do
    user = build(:user, avatar_key: "boy99")

    expect(user).not_to be_valid
  end

  it "allows teacher and admin avatar_key values" do
    expect(build(:user, :teacher, gender: "male", avatar_key: "teacherM08")).to be_valid
    expect(build(:user, :teacher, gender: "female", avatar_key: "teacherF06")).to be_valid
    expect(build(:user, :admin, gender: nil, avatar_key: "admin")).to be_valid
    expect(build(:user, :admin, gender: nil, avatar_key: "teacherM08")).to be_valid
  end

  it "rejects role-incompatible avatar_key changes" do
    expect(build(:user, :student, avatar_key: "teacherM01")).not_to be_valid
    expect(build(:user, :teacher, avatar_key: "boy01")).not_to be_valid
    expect(build(:user, :admin, avatar_key: "girl01")).not_to be_valid
  end

  it "allows unrelated updates for a legacy role-incompatible avatar_key" do
    teacher = create(:user, :teacher, avatar_key: "teacherM01")
    teacher.update_column(:avatar_key, "boy01")

    expect(teacher.update(name: "Updated Teacher")).to eq(true)
  end

  describe "role-specific Devise credentials" do
    it "allows students without email or Devise password" do
      student = build(:user, :student, email: nil, password: nil, student_pin: "1234")

      expect(student).to be_valid
      student.save!
      expect(student.reload.email).to be_nil
      expect(student.encrypted_password).to eq("")
      expect(student.authenticate_student_pin("1234")).to be_truthy
    end

    it "allows multiple students with nil email" do
      create(:user, :student, email: nil)

      expect { create(:user, :student, email: nil) }.to change(described_class.student, :count).by(1)
    end

    it "keeps student PIN validation" do
      student = build(:user, :student, student_pin: "12ab")

      expect(student).not_to be_valid
    end

    it "requires email for teachers and admins" do
      expect(build(:user, :teacher, email: nil)).not_to be_valid
      expect(build(:user, :admin, email: nil)).not_to be_valid
    end

    it "requires password for new teachers" do
      teacher = build(:user, :teacher, password: nil)

      expect(teacher).not_to be_valid
    end

    it "keeps case-insensitive email uniqueness for staff accounts" do
      create(:user, :teacher, email: "staff@example.com")

      expect(build(:user, :admin, email: "STAFF@example.com")).not_to be_valid
    end

    it "clears student email and Devise password assignments without normalization errors" do
      student = create(:user, :student, email: "Student@Example.com", password: "password123")

      expect(student.reload.email).to be_nil
      expect(student.encrypted_password).to eq("")
    end
  end
end
