class SchoolClosure < ApplicationRecord
  belongs_to :school

  validates :name, :starts_on, :ends_on, presence: true
  validates :ends_on,
    comparison: { greater_than_or_equal_to: :starts_on },
    if: -> { starts_on.present? && ends_on.present? }
end
