class UserCouponsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:index, :use]
  before_action :set_classroom_and_student, only: :create

  def create
    authorize @classroom, :draw_coupon?

    template = policy_scope(CouponTemplate)
      .active
      .find(params.require(:coupon_template_id))

    @coupon = UserCoupons::Issue.call!(
      user: @user,
      classroom: @classroom,
      template: template,
      issued_by: current_user,
      issuance_basis: "manual",
      period_start_on: UserCoupon.period_start_for("manual"),
      basis_tag: "selected"
    )

    load_use_stream_data!(user: @user, classroom_id: @classroom.id)
    @pending_coupon_use_requests_by_coupon_id = CouponUseRequest
      .pending
      .where(user_coupon_id: @coupons.select(:id))
      .index_by(&:user_coupon_id)
    broadcast_student_coupon_lists
    message = t("coupons.assign.success", title: template.title)

    respond_to do |format|
      format.html do
        redirect_to classroom_student_path(@classroom, @user),
          notice: message,
          status: :see_other
      end
      format.turbo_stream do
        flash.now[:notice] = message
        render :create, layout: "application"
      end
      format.json do
        render json: { coupon_id: @coupon.id, user_id: @user.id }, status: :created
      end
    end
  end

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

    pending_request = @coupon.with_lock do
      if @coupon.coupon_use_requests.pending.exists?
        true
      else
        UserCoupons::Use.call!(coupon: @coupon, actor: current_user)
        false
      end
    end

    if pending_request
      return render_use_conflict(
        message: t("coupons.use.pending_request"),
        error: "pending_request"
      )
    end

    @play_coupon_animation = true

    load_use_stream_data!(user: @user, classroom_id: @coupon.classroom_id)
    broadcast_student_coupon_lists

    respond_to do |f|
      f.html { redirect_to user_path(@user), notice: t("coupons.use.success"), status: :see_other }

      f.turbo_stream  do
        flash.now[:notice] = t("coupons.use.success")
        render :use, layout: "application"
      end
      f.json { render json: { ok: true, used_at: @coupon.used_at }, status: :ok }
    end

  rescue UserCoupons::Use::InactiveStudentError
    @play_coupon_animation = false
    render_use_conflict(
      message: t("coupons.use.inactive_student"),
      error: "inactive_student"
    )
  rescue ActiveRecord::RecordInvalid
    @play_coupon_animation = false
    message = t("coupons.use.already_used")
    render_use_conflict(message: message, error: message)
  end

  private

  def render_use_conflict(message:, error:)
    load_use_stream_data!(user: @user, classroom_id: @coupon.classroom_id)
    respond_to do |f|
      f.html { redirect_to user_path(@user), alert: message, status: :conflict }
      f.turbo_stream  do
        flash.now[:alert] = message
        render :use, layout: "application", status: :conflict
      end
      f.json { render json: { ok: false, error: error }, status: :conflict }
    end
  end

  def set_user
    @user = User.find(params[:user_id])
    authorize @user, :show?  # 학생 상세/자원 접근 권한
  end

  def set_classroom_and_student
    @classroom = Classroom.find(params[:classroom_id])
    membership = @classroom.classroom_memberships.find_by!(
      user_id: params[:student_id],
      role: "student",
      status: "active"
    )
    @user = membership.user
  end

  def load_use_stream_data!(user:, classroom_id:)
    @coupons = issued_coupons_for(user: user, classroom_id: classroom_id)

    @recent_issued_coupons = policy_scope(UserCoupon)
      .where(user_id: user.id, classroom_id: classroom_id)
      .includes(:coupon_template, :user)
      .order(issued_at: :desc)
      .limit(10)

    @kpi_counts = build_kpi_counts_for(user: user, classroom_id: classroom_id)
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

  def broadcast_student_coupon_lists
    broadcast_student_coupon_list(stream: :student_coupons, viewer: @user)
    broadcast_student_coupon_list(stream: :managed_coupons, viewer: nil)
  end

  def broadcast_student_coupon_list(stream:, viewer:)
    safely_broadcast_realtime(
      tag: stream,
      actor_id: current_user.id,
      classroom_id: @coupon.classroom_id,
      student_id: @user.id,
      coupon_id: @coupon.id
    ) do
      Turbo::StreamsChannel.broadcast_update_to(
        @user,
        stream,
        target: view_context.dom_id(@user, :coupons),
        partial: "user_coupons/list",
        locals: {
          coupons: @coupons,
          user: @user,
          viewer: viewer,
          pending_coupon_use_requests_by_coupon_id: CouponUseRequest
            .pending
            .where(user_coupon_id: @coupons.select(:id))
            .index_by(&:user_coupon_id)
        }
      )
    end
  end

  def issued_coupons_for(user:, classroom_id:)
    policy_scope(UserCoupon)
      .where(user_id: user.id, classroom_id: classroom_id, status: "issued")
      .includes(:coupon_template)
      .order(issued_at: :desc)
  end

end
