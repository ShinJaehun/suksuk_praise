class Admin::CouponEventsController < Admin::BaseController

  def index
    authorize CouponEvent

    # ✅ 드롭다운 데이터 준비
    @classrooms = policy_scope(Classroom).select(:id, :name).order(:name)
    @templates  = CouponTemplate.active.select(:id, :title).order(:title)

    @classroom_options = [[t("reports.defaults.all_classrooms", default: "전체 교실"), ""]] +
                        @classrooms.map { |c| [c.name, c.id] }

    @template_options  = [[t("reports.defaults.all_templates", default: "전체 쿠폰"), ""]] +
                        @templates.map { |t| [t.title, t.id] }

    @period_options = [
      [t("reports.periods.all_time",     default: "전체 기간"),    "all_time"],
      [t("reports.periods.last_30_days", default: "최근 30일"),    "last_30_days"],
      [t("reports.periods.last_7_days",  default: "최근 7일"),     "last_7_days"],
      [t("reports.periods.this_month",   default: "이번 달"),      "this_month"],
      [t("reports.periods.this_week",    default: "이번 주"),      "this_week"],
      [t("reports.periods.today",        default: "오늘"),         "today"],
      [t("reports.periods.custom",       default: "직접 지정"),     "custom"], # 추후 구현
    ]
                        
    scope = policy_scope(CouponEvent)
              .includes(:actor, :classroom, :coupon_template, user_coupon: :user)

    scope = scope.where(classroom_id: params[:classroom_id]) if params[:classroom_id].present?
    scope = scope.where(coupon_template_id: params[:template_id]) if params[:template_id].present?

    period_key = params[:period].presence || "last_7_days"
    if (range = period_range(period_key))
      scope = scope.where(created_at: range)
    end

    @events = scope.order(sort_clause(params[:sort])).limit(200)
  end

  private
  
  def period_range(key)
    now = Time.zone.now
    case key
    when "all_time"     then nil
    when "last_30_days" then (now - 30.days)..now
    when "last_7_days"  then (now - 7.days)..now
    when "this_month"   then now.beginning_of_month..now.end_of_month
    when "this_week"    then now.beginning_of_week(:monday)..now.end_of_week(:monday)
    when "today"        then now.beginning_of_day..now.end_of_day
    when "custom"       then nil # TODO: start_date/end_date 붙일 때 구현
    else nil
    end
  end

  def sort_clause(key)
    key == "issued_at_asc" ? { created_at: :asc } : { created_at: :desc }
  end
end
