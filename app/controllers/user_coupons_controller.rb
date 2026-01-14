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

    UserCoupons::Use.call!(coupon: @coupon, actor: current_user)

    load_recent_issued_coupons!(user: @user, classroom_id: @coupon.classroom_id)

    respond_to do |f|
      f.html { redirect_to user_path(@user), notice: t("coupons.use.success"), status: :see_other }

      f.turbo_stream  do
        flash.now[:notice] = t("coupons.use.success")
        render :use, layout: "application"
      end
      f.json { render json: { ok: true, used_at: @coupon.used_at }, status: :ok }
    end

  rescue ActiveRecord::RecordInvalid
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
      .where(user_id: user.id, classroom_id: classroom_id, status: "issued")
      .includes(:coupon_template)
      .order(issued_at: :desc)
  end
end