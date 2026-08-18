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
      broadcast_student_card_alerts(@coupon_use_request)
      broadcast_student_coupon_lists(@coupon_use_request)
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
    broadcast_student_card_alerts(@coupon_use_request)
    broadcast_student_coupon_lists(@coupon_use_request)
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

  def broadcast_student_card_alerts(coupon_use_request)
    broadcast_student_card_alerts_for(coupon_use_request.classroom, coupon_use_request.student)
  end

  def broadcast_student_coupon_lists(coupon_use_request)
    broadcast_student_coupon_list(coupon_use_request, stream: :student_coupons, viewer: coupon_use_request.student)
    broadcast_student_coupon_list(coupon_use_request, stream: :managed_coupons, viewer: nil)
  end

  def broadcast_student_coupon_list(coupon_use_request, stream:, viewer:)
    student = coupon_use_request.student

    safely_broadcast_realtime(
      tag: stream,
      actor_id: current_user.id,
      classroom_id: coupon_use_request.classroom_id,
      student_id: student.id,
      coupon_id: coupon_use_request.user_coupon_id,
      coupon_use_request_id: coupon_use_request.id
    ) do
      Turbo::StreamsChannel.broadcast_update_to(
        student,
        stream,
        target: view_context.dom_id(student, :coupons),
        partial: "user_coupons/list",
        locals: student_coupon_list_locals(coupon_use_request).merge(viewer: viewer)
      )
    end
  end

  def student_coupon_list_locals(coupon_use_request)
    student = coupon_use_request.student
    classroom = coupon_use_request.classroom
    coupons = UserCoupon
      .where(user_id: student.id, classroom_id: classroom.id, status: "issued")
      .includes(:coupon_template)
      .order(issued_at: :desc)

    {
      coupons: coupons,
      user: student,
      pending_coupon_use_requests_by_coupon_id: CouponUseRequest
        .pending
        .where(user_coupon_id: coupons.select(:id))
        .index_by(&:user_coupon_id)
    }
  end
end
