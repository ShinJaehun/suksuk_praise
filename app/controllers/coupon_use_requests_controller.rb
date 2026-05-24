class CouponUseRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_coupon, only: :create
  before_action :set_coupon_use_request, only: :approve

  def create
    @coupon_use_request = CouponUseRequest.new(
      user_coupon: @coupon,
      classroom: @coupon.classroom,
      student: @coupon.user,
      requested_by: current_user
    )
    authorize @coupon_use_request

    if @coupon_use_request.save
      redirect_back fallback_location: user_path(@user), notice: "쿠폰 사용을 요청했습니다.", status: :see_other
    else
      redirect_back fallback_location: user_path(@user),
        alert: @coupon_use_request.errors.full_messages.to_sentence.presence || "쿠폰 사용 요청을 보낼 수 없습니다.",
        status: :see_other
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_back fallback_location: user_path(@user), alert: "이미 사용 요청 중인 쿠폰입니다.", status: :see_other
  end

  def approve
    authorize @coupon_use_request, :approve?

    @coupon_use_request.approve!(actor: current_user)
    redirect_back fallback_location: classroom_student_path(@coupon_use_request.classroom, @coupon_use_request.student),
      notice: "쿠폰 사용 요청을 승인했습니다.",
      status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_back fallback_location: classroom_student_path(@coupon_use_request.classroom, @coupon_use_request.student),
      alert: "쿠폰 사용 요청을 승인할 수 없습니다.",
      status: :see_other
  end

  private

  def set_user_coupon
    @user = User.find(params[:user_id])
    @coupon = @user.user_coupons.find(params[:user_coupon_id])
  end

  def set_coupon_use_request
    @coupon_use_request = CouponUseRequest.find(params[:id])
  end
end
