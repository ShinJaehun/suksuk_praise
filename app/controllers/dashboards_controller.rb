class DashboardsController < ApplicationController
  include StudentWeeklyDashboardLoader

  PERIODS = %w[week month].freeze
  METRICS = %w[compliments issued used].freeze

  before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    if current_user.student?
      load_student_dashboard
    else
      load_classroom_analytics_dashboard
    end
  end

  private

  def load_student_dashboard
    classroom_id = session[:student_login_classroom_id]
    membership = current_user.classroom_memberships.active.student.includes(:classroom).find_by(classroom_id: classroom_id)

    unless membership
      sign_out(:user)
      return redirect_to student_session_timeout_redirect_path(classroom_id),
        alert: "사용 시간이 지나 자동으로 로그아웃되었습니다. 다시 로그인해 주세요."
    end

    @classroom = membership.classroom
    load_student_weekly_dashboard!(student: current_user, classroom: @classroom)
  end

  def load_classroom_analytics_dashboard
    @show_school_filter = current_user.admin?
    @period = params[:period].presence_in(PERIODS) || "week"
    @metric = params[:metric].presence_in(METRICS) || "compliments"
    set_period_range
    @period_options = PERIODS.map { |period| [t("dashboard.filters.#{period}"), period] }

    @accessible_classrooms = policy_scope(Classroom)
    if @show_school_filter
      @filter_schools = policy_scope(School).order(:name).load
      @selected_school = selected_school
      @available_classrooms = if @selected_school
        @accessible_classrooms.where(school_id: @selected_school.id).order(:name).load
      else
        []
      end
    else
      @available_classrooms = @accessible_classrooms.order(:name).load
    end

    @selected_classroom = selected_classroom
    @selected_classroom ||= @available_classrooms.first if @available_classrooms.one?
    set_selection_prompt
    return unless @selected_classroom

    result = Dashboard::ClassroomAnalytics.call(
      classroom: @selected_classroom,
      time_range: @period_start.beginning_of_day..@period_end.end_of_day,
      metric: @metric
    )
    @student_rows = result.student_rows
    @summary = result.summary
    @metric_links = METRICS.map do |metric|
      {
        key: metric,
        label: t("dashboard.comparison.#{metric}"),
        path: dashboard_path(metric_link_params(metric)),
        active: metric == @metric
      }
    end
    @selected_metric_count_key = "dashboard.counts.#{@metric}"
  end

  def selected_school
    return unless numeric_param?(:school_id)

    @filter_schools.find { |school| school.id == params[:school_id].to_i }
  end

  def selected_classroom
    return unless numeric_param?(:classroom_id)

    @available_classrooms.find { |classroom| classroom.id == params[:classroom_id].to_i } ||
      raise(ActiveRecord::RecordNotFound)
  end

  def numeric_param?(key)
    params[key].to_s.match?(/\A\d+\z/)
  end

  def set_period_range
    today = Time.zone.today
    @period_start = @period == "month" ? today.beginning_of_month : today.beginning_of_week(:monday)
    @period_end = today
  end

  def set_selection_prompt
    @selection_prompt_key = if @show_school_filter && @selected_school.nil?
      "dashboard.prompts.choose_school_and_classroom"
    elsif @available_classrooms.empty?
      "dashboard.prompts.no_classrooms"
    elsif @show_school_filter
      "dashboard.prompts.choose_school_and_classroom"
    else
      "dashboard.prompts.choose_classroom"
    end
  end

  def metric_link_params(metric)
    {
      school_id: @selected_school&.id,
      classroom_id: @selected_classroom.id,
      period: @period,
      metric: metric
    }.compact
  end
end
