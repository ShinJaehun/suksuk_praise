class StudentActivityNote < ApplicationRecord
  SOURCE_TYPES = %w[CouponEvent Compliment].freeze

  belongs_to :student, class_name: "User"
  belongs_to :classroom
  belongs_to :author, class_name: "User"
  belongs_to :source, polymorphic: true

  attr_readonly :source_type, :source_id, :student_id, :classroom_id, :author_id, :occurred_at

  before_validation :assign_source_context, on: :create

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :body, presence: true, length: { maximum: 1_000 }
  validates :occurred_at, presence: true
  validates :author_id, uniqueness: { scope: %i[source_type source_id] }

  private

  def assign_source_context
    case source
    when Compliment
      self.student = source.receiver
      self.classroom = source.classroom
      self.occurred_at = source.given_at
    when CouponEvent
      self.student = source.user_coupon&.user
      self.classroom = source.classroom
      self.occurred_at = source.created_at
    end
  end
end
