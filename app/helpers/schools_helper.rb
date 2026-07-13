module SchoolsHelper
  def school_calendar_day_classes(date:, calendar_month:, today:, closures:, public_holidays:)
    classes = ["school-closure-calendar__day"]
    classes << "school-closure-calendar__day--muted" unless date.month == calendar_month.month
    classes << "school-closure-calendar__day--today" if date == today
    classes << "school-closure-calendar__day--school-closure" if closures.any?
    classes << "school-closure-calendar__day--public-holiday" if public_holidays.any?
    classes.join(" ")
  end

  def school_calendar_day_button_classes(date:, calendar_month:, today:, closures:, public_holidays:)
    classes = school_calendar_day_classes(
      date: date,
      calendar_month: calendar_month,
      today: today,
      closures: closures,
      public_holidays: public_holidays
    ).split
    classes << "school-closure-calendar__day--button"
    classes.join(" ")
  end

  def school_calendar_aria_label(date:, closures:, public_holidays:, today:)
    labels = [I18n.l(date, format: :long)]
    labels << I18n.t("schools.calendar.today") if date == today
    labels << I18n.t("schools.calendar.public_holiday_names", names: public_holidays.map(&:name).join(", ")) if public_holidays.any?
    labels << I18n.t("schools.calendar.school_closure_names", names: closures.map(&:name).join(", ")) if closures.any?
    labels.join(", ")
  end

  def school_closure_period_label(closure)
    if closure.starts_on == closure.ends_on
      I18n.t("schools.show.closure_single_date", date: I18n.l(closure.starts_on, format: :short))
    else
      I18n.t(
        "schools.show.closure_date_range",
        starts_on: I18n.l(closure.starts_on, format: :short),
        ends_on: I18n.l(closure.ends_on, format: :short)
      )
    end
  end
end
