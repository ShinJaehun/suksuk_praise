class CouponUseRequest < ApplicationRecord
  belongs_to :user_coupon
  belongs_to :classroom
  belongs_to :student, class_name: "User"
  belongs_to :requested_by, class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true

  enum status: { pending: 0, approved: 1 }

  validates :requested_at, presence: true
  validates :user_coupon_id,
    uniqueness: {
      conditions: -> { where(status: statuses[:pending]) },
      message: "already has a pending use request"
    },
    if: :pending?
  validate :coupon_must_be_issued, on: :create
  validate :coupon_context_must_match
  validate :requester_must_be_student_owner, on: :create

  before_validation :set_requested_at, on: :create

  def approve!(actor:)
    with_lock do
      return if approved?

      user_coupon.with_lock do
        if user_coupon.issued?
          UserCoupons::Use.call!(coupon: user_coupon, actor: actor)
        end

        update!(status: :approved, resolved_by: actor, resolved_at: Time.current)
      end
    end
  end

  private

  def set_requested_at
    self.requested_at ||= Time.current
  end

  def coupon_must_be_issued
    return if user_coupon&.issued?

    errors.add(:user_coupon, "must be issued")
  end

  def coupon_context_must_match
    return unless user_coupon

    errors.add(:classroom, "must match coupon classroom") if classroom_id != user_coupon.classroom_id
    errors.add(:student, "must match coupon user") if student_id != user_coupon.user_id
  end

  def requester_must_be_student_owner
    return unless requested_by

    errors.add(:requested_by, "must be the student owner") unless requested_by.student? && requested_by_id == student_id
  end
end
