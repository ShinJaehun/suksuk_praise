class SchoolsController < ApplicationController
  include SchoolWorkspacePrepareable

  before_action :authenticate_user!
  before_action :set_school, only: %i[show edit update]

  layout -> { turbo_frame_request? ? false : "application" }

  def index
    @schools = policy_scope(School).order(:name, :id).load
    authorize School

    redirect_to school_path(@schools.first) and return if current_user.teacher? && @schools.one?

    school_ids = @schools.map(&:id)
    @classroom_counts = Classroom.where(school_id: school_ids).group(:school_id).count
    @teacher_counts = SchoolMembership.where(school_id: school_ids).group(:school_id).count
    @managers_by_school_id = SchoolMembership.manager.includes(:user).where(school_id: school_ids).group_by(&:school_id)
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
      prepare_school_overview
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "school_overview",
              partial: "schools/overview",
              locals: school_overview_locals
            ),
            turbo_stream.update("modal", "")
          ]
        end
        format.html do
          redirect_to school_path(@school),
            notice: t("schools.settings.update.success"),
            status: :see_other
        end
      end
    else
      prepare_school_settings
      render_school_settings(status: :unprocessable_entity)
    end
  end

  private

  def set_school
    @school = policy_scope(School).find(params[:id])
  end

  def school_params
    params.require(:school).permit(:name)
  end

  def school_overview_locals
    {
      school: @school,
      classroom_count: @classroom_count,
      teacher_count: @teacher_count,
      managers: @managers
    }
  end

  def render_school_settings(status:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "modal",
          partial: "schools/settings_modal"
        ), status: status
      end
      format.html do
        render :edit, status: status
      end
    end
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
