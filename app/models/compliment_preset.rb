class ComplimentPreset < ApplicationRecord
  MAX_ACTIVE_PER_USER = 5

  belongs_to :user
  has_many :compliments, dependent: :nullify

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  before_validation :normalize_title
  before_validation :assign_position, on: :create

  validates :title, presence: true, length: { maximum: 50 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :active_title_unique_for_user
  validate :active_limit_for_user

  private

  def normalize_title
    self.title = title.to_s.strip if title.present?
  end

  def assign_position
    return if position.present? || user.blank?

    self.position = user.compliment_presets.maximum(:position).to_i + 1
  end

  def active_title_unique_for_user
    return unless active?
    return if title.blank? || user_id.blank?

    matching = self.class.active
      .where(user_id: user_id)
      .where("lower(title) = ?", title.downcase)
    matching = matching.where.not(id: id) if persisted?
    return unless matching.exists?

    errors.add(:title, :taken)
  end

  def active_limit_for_user
    return unless active?
    return if user_id.blank?

    active_presets = self.class.active.where(user_id: user_id)
    active_presets = active_presets.where.not(id: id) if persisted?
    return if active_presets.count < MAX_ACTIVE_PER_USER

    errors.add(:base, :too_many_active_presets)
  end
end
