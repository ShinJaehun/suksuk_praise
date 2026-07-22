require "rails_helper"

RSpec.describe CouponTemplate, type: :model do
  def insert_coupon_template!(attrs)
    now = Time.current

    described_class.insert!(
      {
        title: "DB Coupon",
        weight: 10,
        active: true,
        bucket: "personal",
        created_at: now,
        updated_at: now
      }.merge(attrs)
    )
  end

  describe "title uniqueness" do
    it "rejects titles that differ only by case for the same user and bucket" do
      teacher = create(:user, :teacher)
      create(:coupon_template, created_by: teacher, bucket: "personal", title: "Reward")

      duplicate = build(:coupon_template, created_by: teacher, bucket: "personal", title: "reward")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:title]).to be_present
    end

    it "rejects case-only duplicates at the database level" do
      teacher = create(:user, :teacher)
      create(:coupon_template, created_by: teacher, bucket: "personal", title: "Reward")

      expect {
        insert_coupon_template!(
          created_by_id: teacher.id,
          bucket: "personal",
          title: "reward"
        )
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same title for different users or buckets" do
      teacher = create(:user, :teacher)
      other_teacher = create(:user, :teacher)

      create(:coupon_template, created_by: teacher, bucket: "personal", title: "Shared")

      expect(build(:coupon_template, created_by: other_teacher, bucket: "personal", title: "shared")).to be_valid
      expect(build(:coupon_template, created_by: teacher, bucket: "library", title: "shared")).to be_valid
    end
  end

  describe "source template uniqueness" do
    it "keeps database-level duplicate prevention by source template" do
      admin = create(:user, :admin)
      teacher = create(:user, :teacher)
      source = create(:coupon_template, created_by: admin, bucket: "library", title: "Library Source")
      create(:coupon_template, created_by: teacher, bucket: "personal", title: "First", source_template: source)

      expect {
        insert_coupon_template!(
          created_by_id: teacher.id,
          bucket: "personal",
          title: "Second",
          source_template_id: source.id
        )
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
