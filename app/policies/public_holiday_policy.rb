class PublicHolidayPolicy < ApplicationPolicy
  def sync?
    admin?
  end
end
