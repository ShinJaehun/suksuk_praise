require "rails_helper"

RSpec.describe Compliment, type: :model do
  it "is valid with a giver, receiver, classroom, and given_at" do
    classroom = create(:classroom)
    giver = create(:user, :teacher)
    receiver = create(:user, :student)

    compliment = described_class.new(
      classroom: classroom,
      giver: giver,
      receiver: receiver,
      given_at: Time.zone.local(2026, 4, 7, 10, 0, 0)
    )

    expect(compliment).to be_valid
  end

  it "requires a classroom" do
    compliment = build(:compliment, classroom: nil)

    expect(compliment).not_to be_valid
  end

  it "requires given_at" do
    compliment = build(:compliment, given_at: nil)

    expect(compliment).not_to be_valid
  end

  it "allows a custom compliment preset and reason snapshot" do
    preset = create(:compliment_preset, title: "친구를 도움")
    compliment = build(:compliment, compliment_preset: preset, giver: preset.user, reason: "친구를 도움")

    expect(compliment).to be_valid
  end
end
