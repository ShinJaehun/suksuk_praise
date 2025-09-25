class UserCouponsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  # before_action :require_teacher_or_admin!

  def index
    # 학생은 본인 것만, 교사/관리자는 조회 허용 (원하면 더 엄격히 제한 가능)
    return head :forbidden unless current_user == @user ||
      current_user.teacher? || current_user.admin?

    @coupons = @user.user_coupons.where(status: "issued").order(created_at: :desc)
  end

  # POST /users/:user_id/coupons/:id/use
  def use
    return head :forbidden unless current_user == @user ||
      current_user.teacher? || current_user.admin?

    coupon = @user.user_coupons.find(params[:id])
    return render json: { error: "이미 사용된 쿠폰입니다." }, status: :conflict if coupon.used?

    coupon.use!  # 사용 시 제한 없음(요청하신 규칙)
    @coupon = coupon
    
    respond_to do |f|
      f.json  { render json: { ok: true, used_at: coupon.used_at }, status: :ok }
      f.turbo_stream { flash.now[:notice] = "쿠폰을 사용했습니다." }
      f.html  { redirect_to user_path(@user), notice: "쿠폰을 사용했습니다." }
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
    authorize @user, :show?  # 학생 상세를 볼 권한
  end

  # def require_teacher_or_admin!
  #   head :forbidden unless current_user&.teacher? || current_user&.admin?
  # end
end