require "rails_helper"

RSpec.describe UsersHelper, type: :helper do
  describe "#user_avatar_path" do
    it "uses avatar_key before the default avatar index" do
      user = build(:user, avatar_key: "girl01", default_avatar_index: 7)

      expect(helper.user_avatar_path(user, size: 128)).to eq("avatars/girl01.png")
    end

    it "falls back to default_avatar_index" do
      user = build(:user, avatar_key: nil, default_avatar_index: 7)

      expect(helper.user_avatar_path(user, size: 128)).to eq("avatars/user_profile_07_128.png")
    end
  end
end
