module SchoolsHelper
  SCHOOL_COLOR_SWATCH_CLASSES = {
    "sky" => "bg-sky-500",
    "emerald" => "bg-emerald-500",
    "violet" => "bg-violet-500",
    "amber" => "bg-amber-500",
    "rose" => "bg-rose-500",
    "teal" => "bg-teal-500",
    "indigo" => "bg-indigo-500",
    "orange" => "bg-orange-500"
  }.freeze

  SCHOOL_COLOR_CARD_CLASSES = {
    "sky" => "border-sky-200 bg-sky-50/70",
    "emerald" => "border-emerald-200 bg-emerald-50/70",
    "violet" => "border-violet-200 bg-violet-50/70",
    "amber" => "border-amber-200 bg-amber-50/70",
    "rose" => "border-rose-200 bg-rose-50/70",
    "teal" => "border-teal-200 bg-teal-50/70",
    "indigo" => "border-indigo-200 bg-indigo-50/70",
    "orange" => "border-orange-200 bg-orange-50/70"
  }.freeze

  SCHOOL_COLOR_ROW_CLASSES = {
    "sky" => "border-l-4 border-l-sky-400 bg-sky-50/60",
    "emerald" => "border-l-4 border-l-emerald-400 bg-emerald-50/60",
    "violet" => "border-l-4 border-l-violet-400 bg-violet-50/60",
    "amber" => "border-l-4 border-l-amber-400 bg-amber-50/60",
    "rose" => "border-l-4 border-l-rose-400 bg-rose-50/60",
    "teal" => "border-l-4 border-l-teal-400 bg-teal-50/60",
    "indigo" => "border-l-4 border-l-indigo-400 bg-indigo-50/60",
    "orange" => "border-l-4 border-l-orange-400 bg-orange-50/60"
  }.freeze

  def school_color_swatch_class(color_key)
    SCHOOL_COLOR_SWATCH_CLASSES.fetch(color_key, "bg-slate-400")
  end

  def school_color_card_class(color_key)
    SCHOOL_COLOR_CARD_CLASSES.fetch(color_key, "border-slate-200 bg-white")
  end

  def school_color_row_class(color_key)
    SCHOOL_COLOR_ROW_CLASSES.fetch(color_key, "border-l-4 border-l-slate-200 bg-white")
  end

  def school_calendar_day_classes(date:, calendar_month:, today:, closures:, public_holidays:)
    classes = ["school-closure-calendar__day"]
    classes << "school-closure-calendar__day--saturday" if date.saturday?
    classes << "school-closure-calendar__day--sunday" if date.sunday?
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

  def school_calendar_weekday_classes(index)
    classes = ["school-closure-calendar__weekday"]
    classes << "school-closure-calendar__weekday--sunday" if index.zero?
    classes << "school-closure-calendar__weekday--saturday" if index == 6
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
