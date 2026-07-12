class PublicHoliday < ApplicationRecord
  validates :date, :name, :source, presence: true
  validates :date, uniqueness: { scope: %i[name source] }
end
