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

    UserCoupons::Use.call!(coupon: @coupon, actor: current_user)
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

  rescue ActiveRecord::RecordInvalid
    @play_coupon_animation = false
    load_use_stream_data!(user: @user, classroom_id: @coupon.classroom_id)
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

  def reveal_issue
    @coupon = UserCoupon.find(params[:id])
    authorize @coupon, :use?

    user = @coupon.user
    coupons = issued_coupons_for(user: user, classroom_id: @coupon.classroom_id)
    broadcast_student_coupon_list_for(user, coupons)

    head :no_content
  end

  private

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
    coupon_list_locals = {
      coupons: @coupons,
      user: @user,
      pending_coupon_use_requests_by_coupon_id: CouponUseRequest
        .pending
        .where(user_coupon_id: @coupons.select(:id))
        .index_by(&:user_coupon_id)
    }

    Turbo::StreamsChannel.broadcast_update_to(
      @user,
      :student_coupons,
      target: view_context.dom_id(@user, :coupons),
      partial: "user_coupons/list",
      locals: coupon_list_locals.merge(viewer: @user)
    )

    Turbo::StreamsChannel.broadcast_update_to(
      @user,
      :managed_coupons,
      target: view_context.dom_id(@user, :coupons),
      partial: "user_coupons/list",
      locals: coupon_list_locals.merge(viewer: nil)
    )
  end

  def issued_coupons_for(user:, classroom_id:)
    policy_scope(UserCoupon)
      .where(user_id: user.id, classroom_id: classroom_id, status: "issued")
      .includes(:coupon_template)
      .order(issued_at: :desc)
  end

  def broadcast_student_coupon_list_for(student, coupons)
    Turbo::StreamsChannel.broadcast_update_to(
      student,
      :student_coupons,
      target: view_context.dom_id(student, :coupons),
      partial: "user_coupons/list",
      locals: {
        coupons: coupons,
        user: student,
        viewer: student,
        pending_coupon_use_requests_by_coupon_id: CouponUseRequest
          .pending
          .where(user_coupon_id: coupons.select(:id))
          .index_by(&:user_coupon_id)
      }
    )
  end

end
