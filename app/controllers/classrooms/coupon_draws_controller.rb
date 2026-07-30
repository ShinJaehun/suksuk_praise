class Classrooms::CouponDrawsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_draw!

  DUP_WINDOW = 2.seconds

  def draw_coupon
    basis, mode = normalized_basis_and_mode(params[:basis], params[:mode])
    now = Time.current
    @play_coupon_animation = false

    if params[:user_id].present?
      unless ClassroomMembership.exists?(
        user_id: params[:user_id],
        classroom_id: @classroom.id,
        role: "student",
        status: "active"
      )
        message = t("errors.user_not_in_classroom")
        winner = nil
        winner_coupons = nil
        load_recent_issued_coupons!
        respond_to do |format|
          format.html { redirect_to classroom_path(@classroom), alert: message, status: :unprocessable_entity }
          format.turbo_stream do
            flash.now[:alert] = message
            render "classrooms/draw_coupon", layout: "application", status: :unprocessable_entity,
              locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
          end
          format.json { render json: { ok: false, error: "user_not_in_classroom" }, status: :unprocessable_entity }
        end
        return
      end
    end

    issued = nil
    winner = nil
    template = nil
    winner_coupons = nil
    winner_recent_issued_coupons = nil
    winner_kpi_counts = nil
    notice_message = nil

    @classroom.with_lock do
      scope = UserCoupon.where(
        classroom_id: @classroom.id,
        issuance_basis: basis,
        basis_tag: mode
      )
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

      if scope.where("issued_at >= ?", now - DUP_WINDOW).exists?
        message = t("coupons.draw.duplicate")
        load_recent_issued_coupons!
        respond_to do |format|
          format.html do
            redirect_to classroom_path(@classroom), alert: message, status: :conflict
          end
          format.turbo_stream do
            flash.now[:alert] = message
            render "classrooms/draw_coupon", layout: "application", status: :conflict,
              locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
          end
          format.json { render json: { ok: false, error: "duplicate_request" }, status: :conflict }
        end
        return
      end

      issued = CouponDraw::Issue.call(
        classroom: @classroom,
        basis: basis,
        mode: mode,
        issued_by: current_user,
        target_user_id: params[:user_id]
      )

      winner = issued.user
      template = issued.coupon_template
      winner_coupons = policy_scope(UserCoupon)
        .where(user_id: winner.id, classroom_id: @classroom.id, status: "issued")
        .includes(:coupon_template)
        .order(created_at: :desc)
        .load
      winner_recent_issued_coupons = policy_scope(UserCoupon)
        .where(user_id: winner.id, classroom_id: @classroom.id)
        .includes(:coupon_template, :user)
        .order(issued_at: :desc)
        .limit(10)
        .load
      winner_kpi_counts = build_kpi_counts_for(user: winner, classroom: @classroom)

      notice_message = t("coupons.draw.success", name: winner.name, title: template.title)
      @play_coupon_animation = true

      if %w[daily weekly monthly].include?(basis)
        enabled_periods = @classroom.enabled_compliment_king_periods
        @selected_period = basis
        @selected_section = build_compliment_king_sections(enabled_periods: enabled_periods).fetch(@selected_period)
        @issued_winner_ids = build_issued_compliment_king_winner_ids(
          period: @selected_period,
          section: @selected_section
        )
      end
    end

    load_recent_issued_coupons!
    respond_to do |format|
      format.html { redirect_to classroom_path(@classroom), notice: notice_message, status: :see_other }
      format.turbo_stream do
        flash.now[:notice] = notice_message
        render "classrooms/draw_coupon", layout: "application",
          locals: {
            winner: winner,
            winner_coupons: winner_coupons,
            winner_recent_issued_coupons: winner_recent_issued_coupons,
            winner_kpi_counts: winner_kpi_counts,
            issued_coupons: @issued_coupons
          }
      end
      format.json do
        render json: { coupon_id: issued.id, title: template.title, user_id: winner.id },
          status: :created
      end
    end
  rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
    message = t("coupons.draw.already_issued_today")
    load_recent_issued_coupons!
    respond_to do |format|
      format.html { redirect_to classroom_path(@classroom), alert: message, status: :conflict }
      format.turbo_stream do
        flash.now[:alert] = message
        render "classrooms/draw_coupon", layout: "application", status: :conflict,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      format.json { render json: { ok: false, error: "already_issued_today" }, status: :conflict }
    end
  rescue ActiveRecord::RecordNotFound => e
    message = t("coupons.draw.not_found")
    load_recent_issued_coupons!
    respond_to do |format|
      format.html { redirect_to classroom_path(@classroom), alert: message, status: :not_found }
      format.turbo_stream do
        flash.now[:alert] = message
        render "classrooms/draw_coupon", layout: "application", status: :not_found,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      format.json { render json: { ok: false, error: "not_found", detail: e.message }, status: :not_found }
    end
  rescue CouponDraw::Issue::Error => e
    message = t(e.i18n_key)
    load_recent_issued_coupons!
    respond_to do |format|
      format.html { redirect_to classroom_path(@classroom), alert: message, status: e.http_status }
      format.turbo_stream do
        flash.now[:alert] = message
        render "classrooms/draw_coupon", layout: "application", status: e.http_status,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      format.json { render json: { ok: false, error: "invalid", detail: e.i18n_key }, status: e.http_status }
    end
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    message = t("coupons.draw.invalid", reason: e.message)
    load_recent_issued_coupons!
    respond_to do |format|
      format.html { redirect_to classroom_path(@classroom), alert: message, status: :unprocessable_entity }
      format.turbo_stream do
        flash.now[:alert] = message
        render "classrooms/draw_coupon", layout: "application", status: :unprocessable_entity,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      format.json { render json: { ok: false, error: "invalid", detail: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def authorize_draw!
    authorize @classroom, :draw_coupon?
  end

  def load_recent_issued_coupons!
    @issued_coupons = policy_scope(UserCoupon).where(classroom_id: @classroom.id)
      .includes(:user, :coupon_template)
      .order(created_at: :desc)
      .limit(5)
      .load
  end

  def build_compliment_king_sections(enabled_periods:)
    Classroom::COMPLIMENT_KING_PERIODS.filter_map do |period|
      next unless enabled_periods.include?(period)

      [period, ComplimentKings::Pick.call(classroom: @classroom, period: period)]
    end.to_h
  end

  def build_issued_compliment_king_winner_ids(period:, section:)
    return [] unless section.present? && section.winners.present?

    UserCoupon.where(
      user_id: section.winners.map(&:id),
      classroom_id: @classroom.id,
      issuance_basis: period,
      basis_tag: "#{period}_top",
      period_start_on: UserCoupon.period_start_for(period)
    ).pluck(:user_id)
  end

  def normalized_basis_and_mode(basis_param, mode_param)
    basis = case basis_param
            when "manual" then "manual"
            when "weekly" then "weekly"
            when "monthly" then "monthly"
            else "daily"
            end
    mode = if mode_param.present?
             mode_param.to_s
           else
             basis == "manual" ? "default" : "#{basis}_top"
           end

    [basis, mode]
  end

  def build_kpi_counts_for(user:, classroom:)
    compliments_scope = policy_scope(Compliment).where(receiver_id: user.id, classroom_id: classroom.id)
    coupons_scope = policy_scope(UserCoupon).where(user_id: user.id, classroom_id: classroom.id)

    {
      points: user.points,
      today_compliments: compliments_scope.where(given_at: Time.zone.today.all_day).count,
      issued_count: coupons_scope.where(status: "issued").count,
      today_issued_coupons: coupons_scope.where(issued_at: Time.zone.today.all_day).count,
      used_coupons: coupons_scope.where(status: "used").count
    }
  end
end
