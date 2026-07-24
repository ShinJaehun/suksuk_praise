require "rails_helper"

RSpec.describe ComplimentPreset, type: :model do
  let(:user) { create(:user, :teacher) }

  it "belongs to a user and not to a classroom" do
    expect(described_class.reflect_on_association(:user)).to be_present
    expect(described_class.reflect_on_association(:classroom)).to be_nil
  end

  it "requires a user" do
    preset = build(:compliment_preset, user: nil)

    expect(preset).not_to be_valid
  end

  it "rejects blank titles" do
    preset = build(:compliment_preset, user: user, title: "")

    expect(preset).not_to be_valid
  end

  it "strips title before validation" do
    preset = create(:compliment_preset, user: user, title: "  친구를 도움  ")

    expect(preset.title).to eq("친구를 도움")
  end

  it "rejects duplicate active titles for the same user" do
    create(:compliment_preset, user: user, title: "친구를 도움")

    preset = build(:compliment_preset, user: user, title: "친구를 도움")

    expect(preset).not_to be_valid
  end

  it "allows the same active title for another user" do
    create(:compliment_preset, user: user, title: "친구를 도움")

    preset = build(:compliment_preset, user: create(:user, :teacher), title: "친구를 도움")

    expect(preset).to be_valid
  end

  it "allows reusing an inactive title for the same user" do
    create(:compliment_preset, user: user, title: "친구를 도움", active: false)

    preset = build(:compliment_preset, user: user, title: "친구를 도움")

    expect(preset).to be_valid
  end

  it "limits active presets per user to five" do
    create_list(:compliment_preset, 5, user: user)

    preset = build(:compliment_preset, user: user)

    expect(preset).not_to be_valid
  end

  it "does not count another user's active presets toward the limit" do
    create_list(:compliment_preset, 5, user: user)

    preset = build(:compliment_preset, user: create(:user, :teacher))

    expect(preset).to be_valid
  end

  it "orders presets by user-specific position" do
    third = create(:compliment_preset, user: user, title: "셋째", position: 3)
    first = create(:compliment_preset, user: user, title: "첫째", position: 1)
    second = create(:compliment_preset, user: user, title: "둘째", position: 2)

    expect(user.compliment_presets.ordered).to eq([first, second, third])
  end
end
