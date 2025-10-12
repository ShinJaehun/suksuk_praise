class UserCouponsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def index
    @coupons = policy_scope(UserCoupon)
      .where(user_id: @user.id, status: "issued")
      .includes(:coupon_template)
      .order(created_at: :desc)
  end

  # POST /users/:user_id/coupons/:id/use
  def use
    @coupon = @user.user_coupons.find(params[:id])
    authorize @coupon, :use?

    if @coupon.used?
      message = t("coupons.use.already_used") 
      respond_to do |f|
        f.html { redirect_to user_path(@user), alert: message, status: :conflict }
        f.turbo_stream  do
          flash.now[:alert] = message
          render :use, layout: "application", status: :conflict 
        end
        f.json { render json: { ok: false, error: t("coupons.use.already_used") }, status: :conflict }
      end
      return
    end

    @coupon.use! # 규칙상 제한 없음

    CouponEvent.create!(
      action: "used",
      actor: current_user,
      user_coupon: @coupon,
      classroom: @coupon.classroom,
      coupon_template: @coupon.coupon_template,
      metadata: {
        target_user_id: @coupon.user_id,
        target_user_name: @coupon.user.name
      }
    )

    message = t("coupons.use.success")
    respond_to do |f|
      f.html { redirect_to user_path(@user), notice: message, status: :see_other }
      f.turbo_stream  do
        flash.now[:notice] = message
        render :use, layout: "application"
      end
      f.json { render json: { ok: true, used_at: @coupon.used_at }, status: :ok }
    end

  end

  private

  def set_user
    @user = User.find(params[:user_id])
    authorize @user, :show?  # 학생 상세/자원 접근 권한
  end
end