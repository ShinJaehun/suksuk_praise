class Classrooms::ComplimentKingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_refresh!

  def refresh_compliment_king
    enabled_periods = @classroom.enabled_compliment_king_periods
    @selected_period = params[:period].presence || "daily"
    raise ActiveRecord::RecordNotFound unless enabled_periods.include?(@selected_period)

    unless @classroom.compliment_king_refresh_available_for?(@selected_period)
      respond_to do |format|
        format.html { redirect_to classroom_path(@classroom) }
        format.turbo_stream { redirect_to classroom_path(@classroom) }
        format.json { head :forbidden }
      end
      return
    end

    @selected_section = ComplimentKings::Pick.call(
      classroom: @classroom,
      period: @selected_period
    )
    @issued_winner_ids = issued_winner_ids(
      period: @selected_period,
      section: @selected_section
    )

    respond_to do |format|
      format.html { redirect_to classroom_path(@classroom) }
      format.turbo_stream do
        render "classrooms/refresh_compliment_king", layout: false
      end
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def authorize_refresh!
    authorize @classroom, :refresh_compliment_king?
  end

  def issued_winner_ids(period:, section:)
    return [] unless section.present? && section.winners.present?

    UserCoupon.where(
      user_id: section.winners.map(&:id),
      classroom_id: @classroom.id,
      issuance_basis: period,
      basis_tag: "#{period}_top",
      period_start_on: UserCoupon.period_start_for(period)
    ).pluck(:user_id)
  end
end
