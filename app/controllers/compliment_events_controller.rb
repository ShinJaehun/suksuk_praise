class ComplimentEventsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize Compliment

    @accessible_classrooms = Classroom.accessible_for_compliments(current_user).order(:name)
    @accessible_classroom_ids = @accessible_classrooms.reorder(nil).pluck(:id)
    @auto_selected_single_classroom = auto_select_single_classroom?
    @classroom_options = [[t("reports.defaults.all_classrooms"), ""]] +
                         @accessible_classrooms.map { |classroom| [classroom.name, classroom.id] }
    @selected_classroom = selected_accessible_classroom
    @show_classroom_select = !@auto_selected_single_classroom
    @invalid_classroom_filter = !@auto_selected_single_classroom && params[:classroom_id].present? && @selected_classroom.blank?
    @selected_student_membership = selected_student_membership
    @student_options = student_filter_options
    @period = selected_period
    @period_options = period_options
    @start_date = params[:start_date].to_s
    @end_date = params[:end_date].to_s
    @kind = params[:kind].presence_in(%w[all general custom]) || "all"
    @kind_options = [
      [t("compliment_events.index.filters.all_kinds"), "all"],
      [t("compliment_events.index.filters.general"), "general"],
      [t("compliment_events.index.filters.custom"), "custom"]
    ]
    @sort = selected_sort
    @sort_options = [
      [t("reports.sort.given_at_desc"), "given_at_desc"],
      [t("reports.sort.given_at_asc"), "given_at_asc"]
    ]

    base = policy_scope(Compliment).includes(:classroom, :giver, :receiver)
    base = base.none if @invalid_classroom_filter
    base = base.where(classroom_id: @selected_classroom.id) if @selected_classroom
    base = apply_student_filter(base)
    base = base.where(reason: [nil, ""]) if @kind == "general"
    base = base.where.not(reason: [nil, ""]) if @kind == "custom"
    base = apply_period_filter(base)

    @summary_total = base.count
    @pagination_params = pagination_params
    @pagy, @compliments = pagy(
      :offset,
      base.order(sort_clause),
      limit: 10,
      request: {
        base_url: request.base_url,
        path: compliment_events_path,
        params: @pagination_params.merge("page" => params[:page]).compact
      }
    )
  end

  private

  def auto_select_single_classroom?
    current_user.teacher? &&
      !current_user.admin? &&
      !current_user.school_membership&.manager? &&
      @accessible_classroom_ids.one?
  end

  def selected_accessible_classroom
    return @accessible_classrooms.first if @auto_selected_single_classroom
    return nil if params[:classroom_id].blank?

    @accessible_classrooms.find { |classroom| classroom.id == params[:classroom_id].to_i }
  end

  def selected_student_membership
    return nil unless @selected_classroom
    return nil if params[:student_membership_id].blank?

    ClassroomMembership.student
                       .where(classroom_id: @selected_classroom.id)
                       .find_by(id: params[:student_membership_id])
  end

  def student_filter_options
    return [] unless @selected_classroom

    memberships = ClassroomMembership.student
                                     .includes(:user)
                                     .where(classroom_id: @selected_classroom.id)
                                     .order(:created_at, :id)
                                     .to_a
    active_memberships, inactive_memberships = memberships.partition(&:active?)

    [[t("compliment_events.index.filters.all_students"), ""]] +
      (active_memberships + inactive_memberships).map { |membership| [membership.user.name, membership.id] }
  end

  def period_options
    %w[all_time last_30_days last_7_days this_month this_week today custom].map do |period|
      [t("reports.periods.#{period}"), period]
    end
  end

  def selected_period
    params[:period].presence_in(%w[all_time last_30_days last_7_days this_month this_week today custom]) || "last_7_days"
  end

  def apply_period_filter(base)
    range = period_range(@period)
    return base if range.nil?
    return base.none if range == :none

    base.where(given_at: range)
  end

  def period_range(period)
    now = Time.zone.now

    case period
    when "all_time" then nil
    when "last_30_days" then (now - 30.days)..now
    when "last_7_days" then (now - 7.days)..now
    when "this_month" then now.beginning_of_month..now.end_of_month
    when "this_week" then now.beginning_of_week(:monday)..now.end_of_week(:monday)
    when "today" then now.beginning_of_day..now.end_of_day
    when "custom" then custom_period_range(now)
    else (now - 7.days)..now
    end
  end

  def custom_period_range(now)
    start_on = parse_date(params[:start_date])
    end_on = parse_date(params[:end_date])
    return nil if start_on.blank? && end_on.blank?
    return :none if start_on && end_on && start_on > end_on

    starts_at = start_on&.beginning_of_day || Time.zone.at(0)
    ends_at = end_on&.end_of_day || now
    starts_at..ends_at
  end

  def parse_date(value)
    return nil if value.blank?

    Time.zone.parse(value)&.to_date
  rescue ArgumentError, TypeError
    nil
  end

  def apply_student_filter(base)
    return base if params[:student_membership_id].blank?
    return base unless @selected_classroom
    return base.none unless @selected_student_membership

    base.where(
      classroom_id: @selected_student_membership.classroom_id,
      receiver_id: @selected_student_membership.user_id
    )
  end

  def selected_sort
    params[:sort].presence_in(%w[given_at_desc given_at_asc]) || "given_at_desc"
  end

  def sort_clause
    @sort == "given_at_asc" ? { given_at: :asc, id: :asc } : { given_at: :desc, id: :desc }
  end

  def pagination_params
    {}.tap do |query|
      query["classroom_id"] = @selected_classroom.id.to_s if @selected_classroom && @show_classroom_select
      query["student_membership_id"] = @selected_student_membership.id.to_s if @selected_student_membership
      query["period"] = @period if @period != "last_7_days"
      query["start_date"] = params[:start_date].to_s if @period == "custom" && parse_date(params[:start_date])
      query["end_date"] = params[:end_date].to_s if @period == "custom" && parse_date(params[:end_date])
      query["kind"] = @kind if @kind != "all"
      query["sort"] = @sort if @sort != "given_at_desc"
    end
  end
end
