class UserCouponsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def index
    @coupons = policy_scope(UserCoupon)
      .where(user_id: @user.id, status: "issued")
      .includes(:coupon_template)
      .order(issued_at: :desc)
  end

  # POST /users/:user_id/coupons/:id/use
  def use
    @coupon = @user.user_coupons.find(params[:id])
    authorize @coupon, :use?
    @play_coupon_animation = false

    UserCoupons::Use.call!(coupon: @coupon, actor: current_user)
    @play_coupon_animation = true

    load_recent_issued_coupons!(user: @user, classroom_id: @coupon.classroom_id)
    @kpi_counts = build_kpi_counts_for(user: @user, classroom_id: @coupon.classroom_id)

    respond_to do |f|
      f.html { redirect_to user_path(@user), notice: t("coupons.use.success"), status: :see_other }

      f.turbo_stream  do
        flash.now[:notice] = t("coupons.use.success")
        render :use, layout: "application"
      end
      f.json { render json: { ok: true, used_at: @coupon.used_at }, status: :ok }
    end

  rescue ActiveRecord::RecordInvalid
    @play_coupon_animation = false
    @kpi_counts = build_kpi_counts_for(user: @user, classroom_id: @coupon.classroom_id)
    message = t("coupons.use.already_used")
    respond_to do |f|
      f.html { redirect_to user_path(@user), alert: message, status: :conflict }
      f.turbo_stream  do
        flash.now[:alert] = message
        render :use, layout: "application", status: :conflict
      end
      f.json { render json: { ok: false, error: message }, status: :conflict }
    end

  end

  private

  def set_user
    @user = User.find(params[:user_id])
    authorize @user, :show?  # 학생 상세/자원 접근 권한
  end

  def load_recent_issued_coupons!(user:, classroom_id:)
    @issued_coupons = policy_scope(UserCoupon)
      .where(user_id: user.id, classroom_id: classroom_id)
      .includes(:coupon_template, :user)
      .order(issued_at: :desc)
      .limit(10)
  end

  def build_kpi_counts_for(user:, classroom_id:)
    compliments_scope = policy_scope(Compliment).where(receiver_id: user.id, classroom_id: classroom_id)
    coupons_scope = policy_scope(UserCoupon).where(user_id: user.id, classroom_id: classroom_id)

    {
      points: user.points,
      today_compliments: compliments_scope.where(given_at: Time.zone.today.all_day).count,
      issued_count: coupons_scope.where(status: "issued").count,
      today_issued_coupons: coupons_scope.where(issued_at: Time.zone.today.all_day).count,
      used_coupons: coupons_scope.where(status: "used").count
    }
  end

end
