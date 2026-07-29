class SchoolsController < ApplicationController
  include SchoolWorkspacePrepareable

  before_action :authenticate_user!
  before_action :set_school, only: %i[show edit update]

  def index
    schools_scope = policy_scope(School)
    if current_user.admin?
      @school_status = params[:status].presence_in(%w[active inactive all]) || "active"
      schools_scope = schools_scope.where(active: @school_status == "active") unless @school_status == "all"
    end
    @schools = schools_scope.order(:name, :id).load
    authorize School

    redirect_to school_path(@schools.first) and return if current_user.active_teacher? && @schools.one?

    school_ids = @schools.map(&:id)
    @classroom_counts = Classroom.where(school_id: school_ids).group(:school_id).count
    @teacher_counts = SchoolMembership.joins(:user).where(school_id: school_ids, users: { active: true }).group(:school_id).count
    @managers_by_school_id = SchoolMembership.manager.joins(:user).includes(:user).where(school_id: school_ids, users: { active: true }).group_by(&:school_id)
    prepare_public_holiday_sync_years if current_user.admin?
  end

  def show
    authorize @school, :show?

    @school_closure = @school.school_closures.new
    prepare_school_workspace
  end

  def edit
    authorize @school, :update?
    prepare_school_settings
  end

  def update
    authorize @school, :update?

    if @school.update(school_params)
      redirect_to edit_school_path(@school),
        notice: t("schools.settings.update.success"),
        status: :see_other
    else
      prepare_school_settings
      render :edit, formats: :html, status: :unprocessable_entity
    end
  end

  private

  def set_school
    @school = policy_scope(School).find(params[:id])
  end

  def school_params
    params.require(:school).permit(:name, :color_key)
  end

  def prepare_public_holiday_sync_years
    current_year = Time.zone.today.year
    @public_holiday_sync_years = [current_year - 1, current_year, current_year + 1]
    date_range = Date.new(@public_holiday_sync_years.min, 1, 1)..Date.new(@public_holiday_sync_years.max, 12, 31)
    @public_holiday_synced_years = PublicHoliday
      .where(source: PublicHolidays::SyncYear::SOURCE, date: date_range)
      .pluck(:date)
      .map(&:year)
      .uniq
  end
end
