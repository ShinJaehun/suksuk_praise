class Admin::PublicHolidaysController < Admin::BaseController
  def sync
    authorize PublicHoliday, :sync?

    year = sync_year_param
    unless year
      redirect_to schools_path,
        alert: t("admin.public_holidays.sync.invalid_year"),
        status: :see_other
      return
    end

    PublicHolidays::SyncYear.call(year: year)
    redirect_to schools_path,
      notice: t("admin.public_holidays.sync.success", year: year),
      status: :see_other
  rescue PublicHolidays::SyncYear::Error,
    PublicHolidays::KasiClient::Error,
    ActiveRecord::RecordInvalid
    redirect_to schools_path,
      alert: t("admin.public_holidays.sync.failure"),
      status: :see_other
  end

  private

  def sync_year_param
    normalized_year(params[:year])
  end

  def normalized_year(value)
    year = Integer(value, exception: false)
    return year if year&.between?(1000, 9999)

    nil
  end
end
