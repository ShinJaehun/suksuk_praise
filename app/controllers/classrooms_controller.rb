# app/controllers/classrooms_controller.rb
class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom, only: [
    :show, :edit, :update, :destroy, :refresh_compliment_king, :draw_coupon
  ]

  def index
    # index는 policy_scope만 요구(verify_policy_scoped 훅 통과)
    @classrooms = policy_scope(Classroom).order(created_at: :desc)
    # authorize Classroom  # <- 불필요 (after_action에서 index는 verify_authorized 제외)
  end

  def show
    authorize @classroom
    @students = @classroom.students.order("users.created_at ASC")

    today = Time.zone.today.all_day
    counts = Compliment.where(classroom: @classroom, given_at: today).group(:receiver_id).count
    if counts.any?
      max = counts.values.max
      @compliment_kings = @students.select { |s| counts[s.id] == max }
      @compliment_king_count = max
    else
      @compliment_kings = []
      @compliment_king_count = 0
    end

    load_recent_issued_coupons!
  end

  def new
    authorize Classroom
    @classroom = Classroom.new
  end

  def create
    authorize Classroom
    @classroom = Classroom.new(classroom_params)
    if @classroom.save
      ClassroomMembership.create!(
        classroom: @classroom,
        user: current_user,
        role: "teacher"
      )
      redirect_to classroom_path(@classroom), notice: t("classrooms.create.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @classroom
  end

  def update
    authorize @classroom
    if @classroom.update(classroom_params)
      redirect_to @classroom, notice: t("classrooms.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @classroom
    @classroom.destroy
    redirect_to classrooms_path, notice: t("classrooms.destroy.success")
  end

  # Turbo로 일간 칭찬왕 영역만 새로고침
  def refresh_compliment_king
    authorize @classroom, :show?
    @students = @classroom.students.order("users.created_at ASC")
    today = Time.zone.today.all_day
    counts = Compliment.where(classroom: @classroom, given_at: today).group(:receiver_id).count
    if counts.any?
      max = counts.values.max
      @compliment_kings = @students.select { |s| counts[s.id] == max }
      @compliment_king_count = max
    else
      @compliment_kings = []
      @compliment_king_count = 0
    end

    respond_to do |f|
      f.turbo_stream { render :refresh_compliment_king, layout: false }
      f.html { redirect_to classroom_path(@classroom) }
    end
  end

  def draw_coupon
    authorize @classroom, :draw_coupon?

    basis, mode = normalized_basis_and_mode(params[:basis], params[:mode])

    # 더블클릭/중복요청 소프트 가드(2초)
    duplicate_window = 2.seconds

    @classroom.with_lock do
      scope = UserCoupon.where(
        classroom_id:   @classroom.id,
        issuance_basis: basis,
        basis_tag:      mode,
        # issued_by_id:   current_user.id # issued_by_id 조건을 빼면 다중 교사 동시 클릭도 소프트 차단
      )
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

      if scope.where("issued_at >= ?", Time.current - duplicate_window).exists?
        flash.now[:alert] = t("coupons.draw.duplicate")
        load_recent_issued_coupons! 
        respond_to do |f|
          f.turbo_stream { render :draw_coupon, layout: "application" } 
          f.html { redirect_to classroom_path(@classroom), alert: t("coupons.draw.duplicate") }
          f.json { render json: { ok: false, error: "duplicate_request" }, status: :conflict }
        end
        return
      end

      # 첫 요청만 여기 도달 → 발급 실행
      issued = CouponDraw::Issue.call(
        classroom:     @classroom,
        basis:         basis,
        mode:          mode,
        issued_by:     current_user,
        target_user_id: params[:user_id]
      )

      # winner   = issued.user
      # template = issued.coupon_template # UserCoupon.issue!(..., template: ...) 구조를 그대로 가정

      # flash.now[:notice] = t("coupons.draw.success", name: winner.name, title: template.title)
      @winner   = issued.user
      template = issued.coupon_template
      @winner_coupons = policy_scope(UserCoupon)
        .where(user_id: @winner.id, classroom_id: @classroom.id, status: "issued")
        .includes(:coupon_template)
        .order(created_at: :desc)
        .load

      flash.now[:notice] = t("coupons.draw.success", name: @winner.name, title: template.title)

    end

    load_recent_issued_coupons! 
    respond_to do |f|
      f.turbo_stream { render :draw_coupon, layout: "application" }
      f.html { redirect_to classroom_path(@classroom), notice: flash.now[:notice] }
      f.json do
         render json: { coupon_id: issued.id, title: template.title, user_id: @winner.id },
          status: :created
      end
    end

  rescue ActiveRecord::RecordNotFound => e
    flash.now[:alert] = t("coupons.draw.not_found")
    load_recent_issued_coupons! 
    respond_to do |f|
      f.turbo_stream { render layout: "application" }
      f.html { redirect_to classroom_path(@classroom), alert: t("coupons.draw.not_found")}
      f.json { render json: { ok: false, error: "not_found", detail: e.message }, status: :not_found }
    end
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    flash.now[:alert] = t("coupons.draw.invalid", reason: e.message)
    load_recent_issued_coupons! 
    respond_to do |f|
      f.turbo_stream { render layout: "application" }
      f.html { redirect_to classroom_path(@classroom), alert: t("coupons.draw.invalid", reason: e.message) }
      f.json { render json: { ok: false, error: "invalid", detail: e.message }, status: :unprocessable_entity }
    end
  rescue CouponDraw::Issue::DuplicatePeriodError
    flash.now[:alert] = t("coupons.draw.already_issued_today")
    load_recent_issued_coupons!
    respond_to do |f|
      f.turbo_stream { render :draw_coupon, layout: "application" }
      f.html { redirect_to classroom_path(@classroom), alert: t("coupons.draw.already_issued_today") }
      f.json { render json: { ok: false, error: "already_issued_today" }, status: :conflict }
    end
  rescue CouponDraw::Issue::NotComplimentKingToday
    flash.now[:alert] = t("coupons.draw.not_today_king")
    load_recent_issued_coupons!
    respond_to do |f|
      f.turbo_stream { render :draw_coupon, layout: "application" }
      f.html { redirect_to classroom_path(@classroom), alert: t("coupons.draw.not_today_king") }
      f.json { render json: { ok: false, error: "not_today_king" }, status: :forbidden }
    end
  rescue StandardError => e
    # 예: 기간 중복/템플릿 없음 등 서비스에서 커스텀 예외를 올린 경우
    flash.now[:alert] = e.message 
    load_recent_issued_coupons! 
    respond_to do |f|
      f.turbo_stream { render layout: "application" }
      f.html { redirect_to classroom_path(@classroom), alert: e.message }
      f.json { render json: { ok: false, error: "failed", detail: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def classroom_params
    params.require(:classroom).permit(:name)
  end
  
  def load_recent_issued_coupons!
    @issued_coupons = @classroom.user_coupons
      .includes(:user, :coupon_template)
      .order(created_at: :desc)
      .limit(5)
      .load
  end

  def normalized_basis_and_mode(basis_param, mode_param)
    basis = case basis_param
            when "manual" then "manual"
            # when "weekly" then "weekly"
            # when "hybrid" then "hybrid"
            else "daily"
            end
    mode = if mode_param.present?
            mode_param.to_s
          else
            basis == "manual" ? "default" : "daily_top"
          end

    [basis, mode]
  end
end
