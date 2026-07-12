class SchoolMembership < ApplicationRecord
  belongs_to :school
  belongs_to :user

  validates :user_id, uniqueness: true
  validate :user_must_be_teacher

  private

  def user_must_be_teacher
    return if user&.teacher?

    errors.add(:user, I18n.t("school_memberships.errors.user_must_be_teacher"))
  end
end
