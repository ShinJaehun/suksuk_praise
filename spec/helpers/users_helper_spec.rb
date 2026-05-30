require "rails_helper"

RSpec.describe UsersHelper, type: :helper do
  describe "#user_avatar_path" do
    it "uses avatar_key" do
      user = build(:user, avatar_key: "girl01")

      expect(helper.user_avatar_path(user, size: 128)).to eq("avatars/girl01.png")
    end

    it "uses admin avatar_key" do
      user = build(:user, :admin, avatar_key: "admin")

      expect(helper.user_avatar_path(user, size: 128)).to eq("avatars/admin.png")
    end

    it "uses teacher avatar_key when the asset exists" do
      user = build(:user, :teacher, gender: "female", avatar_key: "teacherF03")

      expect(helper.user_avatar_path(user, size: 128)).to eq("avatars/teacherF03.png")
    end

    it "falls back to a role based static avatar key" do
      expect(helper.user_avatar_path(build(:user, :admin, avatar_key: nil), size: 128)).to eq("avatars/admin.png")
      expect(helper.user_avatar_path(build(:user, :teacher, gender: "female", avatar_key: nil), size: 128)).to eq("avatars/teacherM01.png")
      expect(helper.user_avatar_path(build(:user, :student, gender: "girl", avatar_key: nil), size: 128)).to eq("avatars/boy01.png")
    end

    it "falls back when an allowed avatar key does not have an asset" do
      allow(helper).to receive(:available_avatar_keys).and_return(User::AVATAR_KEYS - ["teacherF06"])

      user = build(:user, :teacher, gender: "female", avatar_key: "teacherF06")

      expect(helper.user_avatar_path(user, size: 128)).to eq("avatars/teacherM01.png")
    end

    it "falls back when avatar_key is not allowed for the role" do
      expect(helper.user_avatar_path(build(:user, :student, avatar_key: "teacherM01"), size: 128)).to eq("avatars/boy01.png")
      expect(helper.user_avatar_path(build(:user, :teacher, avatar_key: "girl01"), size: 128)).to eq("avatars/teacherM01.png")
      expect(helper.user_avatar_path(build(:user, :admin, avatar_key: "boy01"), size: 128)).to eq("avatars/admin.png")
    end

    it "falls back to boy01 for unknown role context" do
      user = build(:user, avatar_key: nil)
      allow(user).to receive_messages(admin?: false, teacher?: false, student?: false)

      expect(helper.user_avatar_path(user, size: 128)).to eq("avatars/boy01.png")
    end
  end
end
