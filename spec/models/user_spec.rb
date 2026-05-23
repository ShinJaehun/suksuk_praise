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
      expect(described_class.avatar_keys_for("male")).to include("teacherM01", "teacherM10")
    end

    it "returns female teacher avatar keys" do
      expect(described_class.avatar_keys_for("female")).to include("teacherF01", "teacherF10")
    end

    it "returns admin avatar keys" do
      expect(described_class.avatar_keys_for("admin")).to eq(["admin"])
    end

    it "returns an empty array for unknown gender" do
      expect(described_class.avatar_keys_for("unknown")).to eq([])
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
    expect(build(:user, gender: "male", avatar_key: "teacherM10")).to be_valid
    expect(build(:user, gender: "female", avatar_key: "teacherF10")).to be_valid
    expect(build(:user, gender: nil, avatar_key: "admin")).to be_valid
  end
end
