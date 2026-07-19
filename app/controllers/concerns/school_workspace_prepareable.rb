module SchoolWorkspacePrepareable
  extend ActiveSupport::Concern

  private

  def prepare_school_workspace
    prepare_school_overview
    @can_manage_operations = policy(@school).manage_operations?
    prepare_closure_calendar
    @school_closures = @school.school_closures.order(starts_on: :asc, ends_on: :asc, id: :asc)
  end

  def prepare_school_overview
    @classroom_count = @school.classrooms.count
    @teacher_count = @school.school_memberships.count
    @managers = @school.school_memberships.manager.includes(:user).map(&:user)
  end

  def prepare_school_settings
    @managers = @school.school_memberships.manager.includes(:user).order(:id)
    @manager_candidates = @school.school_memberships
      .includes(:user)
      .order(:role, :id)
      .map(&:user)
  end

  def prepare_closure_calendar
    @calendar_month = calendar_month_from_param
    @calendar_month_param = @calendar_month.strftime("%Y-%m")
    @previous_calendar_month_param = @calendar_month.prev_month.strftime("%Y-%m")
    @next_calendar_month_param = @calendar_month.next_month.strftime("%Y-%m")
    @calendar_starts_on = @calendar_month.beginning_of_month.beginning_of_week(:sunday)
    @calendar_ends_on = @calendar_month.end_of_month.end_of_week(:sunday)
    @calendar_weeks = (@calendar_starts_on..@calendar_ends_on).to_a.each_slice(7).to_a
    @today = Time.zone.today

    calendar_range = @calendar_starts_on..@calendar_ends_on
    @calendar_school_closures = @school.school_closures
      .where("starts_on <= ? AND ends_on >= ?", @calendar_ends_on, @calendar_starts_on)
      .order(starts_on: :asc, ends_on: :asc, id: :asc)
      .to_a
    @school_closures_by_date = closures_by_date(@calendar_school_closures, calendar_range)
    @public_holidays_by_date = PublicHoliday.where(date: calendar_range)
      .order(:date, :id)
      .group_by(&:date)
  end

  def calendar_month_param
    calendar_month_from_param.strftime("%Y-%m")
  end

  def calendar_month_from_param
    value = params[:month].to_s
    return Time.zone.today.beginning_of_month unless value.match?(/\A\d{4}-\d{2}\z/)

    Date.strptime("#{value}-01", "%Y-%m-%d")
  rescue ArgumentError
    Time.zone.today.beginning_of_month
  end

  def closures_by_date(closures, range)
    closures.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |closure, grouped|
      ([closure.starts_on, range.begin].max..[closure.ends_on, range.end].min).each do |date|
        grouped[date] << closure
      end
    end
  end
end
