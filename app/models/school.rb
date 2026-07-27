class School < ApplicationRecord
  COLOR_KEYS = %w[
    sky
    emerald
    violet
    amber
    rose
    teal
    indigo
    orange
  ].freeze

  has_many :classrooms, dependent: :restrict_with_error
  has_many :school_memberships, dependent: :restrict_with_error
  has_many :school_closures, dependent: :restrict_with_error
  has_many :teachers, through: :school_memberships, source: :user

  before_validation :assign_color_key, on: :create

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  validates :name, presence: true, length: { maximum: 80 }
  validates :color_key, inclusion: { in: COLOR_KEYS }

  def inactive?
    !active?
  end

  def self.least_used_color_key
    usage_counts = where(color_key: COLOR_KEYS).group(:color_key).count
    COLOR_KEYS.min_by { |key| usage_counts.fetch(key, 0) }
  end

  private

  def assign_color_key
    self.color_key = self.class.least_used_color_key if color_key.nil?
  end
end
