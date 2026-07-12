class SchoolCalendar
  def initialize(school)
    @school = school
  end

  def school_day?(value)
    date = normalize_date(value)

    !date.saturday? && !date.sunday? && !closed_on?(date)
  end

  def last_school_day_of_week(value)
    date = normalize_date(value)
    last_school_day_in(date.beginning_of_week(:monday)..date.end_of_week(:monday))
  end

  def last_school_day_of_month(value)
    date = normalize_date(value)
    last_school_day_in(date.beginning_of_month..date.end_of_month)
  end

  private

  attr_reader :school

  def normalize_date(value)
    return value.to_date if value.is_a?(Date) || value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    raise ArgumentError, "date must be a Date or Time"
  end

  def closed_on?(date)
    school.school_closures
      .where("starts_on <= ? AND ends_on >= ?", date, date)
      .exists?
  end

  def last_school_day_in(range)
    range.to_a.reverse.find { |date| school_day?(date) }
  end
end
