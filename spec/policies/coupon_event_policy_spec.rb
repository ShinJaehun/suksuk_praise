require "rails_helper"

RSpec.describe CouponEventPolicy do
  def create_event(classroom:, actor:)
    student = create(:user, :student)
    create(:classroom_membership, user: student, classroom: classroom, role: "student")
    template = create(:coupon_template, created_by: actor.teacher? ? actor : create(:user, :teacher))
    coupon = create(
      :user_coupon,
      user: student,
      classroom: classroom,
      coupon_template: template,
      issued_by: actor.teacher? ? actor : create(:user, :teacher)
    )

    CouponEvent.create!(
      action: "issued",
      actor: actor,
      user_coupon: coupon,
      classroom: classroom,
      coupon_template: template
    )
  end

  describe "#index?" do
    it "permits admin and teacher" do
      admin = create(:user, :admin)
      teacher = create(:user, :teacher)

      expect(described_class.new(admin, CouponEvent).index?).to eq(true)
      expect(described_class.new(teacher, CouponEvent).index?).to eq(true)
    end

    it "rejects student and guest" do
      student = create(:user, :student)

      expect(described_class.new(student, CouponEvent).index?).to eq(false)
      expect(described_class.new(nil, CouponEvent).index?).to be_falsey
    end
  end

  describe "Scope" do
    it "returns all events for admin" do
      admin = create(:user, :admin)
      event = create_event(classroom: create(:classroom), actor: create(:user, :teacher))
      other_event = create_event(classroom: create(:classroom), actor: create(:user, :teacher))

      resolved = described_class::Scope.new(admin, CouponEvent.all).resolve

      expect(resolved).to contain_exactly(event, other_event)
    end

    it "returns classroom events and actor events for teacher" do
      teacher = create(:user, :teacher)
      classroom = create(:classroom)
      outside_classroom = create(:classroom)
      create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")

      classroom_event = create_event(classroom: classroom, actor: create(:user, :admin))
      actor_event = create_event(classroom: outside_classroom, actor: teacher)
      create_event(classroom: outside_classroom, actor: create(:user, :teacher))

      resolved = described_class::Scope.new(teacher, CouponEvent.all).resolve

      expect(resolved).to contain_exactly(classroom_event, actor_event)
    end

    it "returns no events for student and guest" do
      event = create_event(classroom: create(:classroom), actor: create(:user, :teacher))
      student = create(:user, :student)

      expect(described_class::Scope.new(student, CouponEvent.all).resolve).not_to include(event)
      expect(described_class::Scope.new(nil, CouponEvent.all).resolve).to be_empty
    end
  end
end
