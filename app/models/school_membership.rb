class SchoolMembership < ApplicationRecord
  belongs_to :school
  belongs_to :user

  enum :role, { member: 0, manager: 10 }, default: :member

  validates :user_id, uniqueness: true
  validate :user_must_be_teacher
  validate :manager_must_be_active, if: :new_manager_assignment?

  private

  def new_manager_assignment?
    manager? && (
      new_record? ||
      will_save_change_to_role? ||
      will_save_change_to_user_id?
    )
  end

  def manager_must_be_active
    return if user&.active?

    errors.add(:base, I18n.t('school_memberships.errors.inactive_manager'))
  end

  def user_must_be_teacher
    return if user&.teacher?

    errors.add(:user, I18n.t('school_memberships.errors.user_must_be_teacher'))
  end
end
