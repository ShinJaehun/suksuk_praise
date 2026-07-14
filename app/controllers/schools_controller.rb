class SchoolsController < ApplicationController
  include SchoolWorkspacePrepareable

  before_action :authenticate_user!

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
    @school = policy_scope(School).find(params[:id])
    authorize @school, :show?

    @school_closure = @school.school_closures.new
    prepare_school_workspace
  end

  private

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
