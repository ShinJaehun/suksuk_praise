# app/controllers/classrooms_controller.rb
require "base64"
require "set"

class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_students_to_mypage!, only: [:index, :show]
  before_action :set_classroom, only: [
    :show, :edit, :update, :destroy, :refresh_compliment_king, :draw_coupon, :student_login_qr, :download_student_login_qr, :regenerate_student_login_token
  ]
  
  # 더블클릭/중복요청 소프트 가드(2초)
  DUP_WINDOW = 2.seconds

  def index
    # index는 policy_scope만 요구(verify_policy_scoped 훅 통과)
    @classrooms = policy_scope(Classroom).order(created_at: :desc)
    @classrooms_index_title = current_user.admin? ? "교실 관리" : "내 교실"
    classroom_ids = @classrooms.map(&:id)
    @manageable_classroom_ids =
      if current_user.admin?
        classroom_ids.to_set
      elsif current_user.teacher?
        current_user.classroom_memberships.where(role: "teacher", classroom_id: classroom_ids).pluck(:classroom_id).to_set
      else
        Set.new
      end
    # authorize Classroom  # <- 불필요 (after_action에서 index는 verify_authorized 제외)
  end

  def show
    authorize @classroom
    @can_manage_classroom = policy(@classroom).update?
    @students = @classroom.students.order(created_at: :asc)
    @enabled_compliment_king_periods = @classroom.enabled_compliment_king_periods
    @compliment_king_sections = build_compliment_king_sections(enabled_periods: @enabled_compliment_king_periods)
    @compliment_king_period_cards = build_compliment_king_period_cards(enabled_periods: @enabled_compliment_king_periods)
    @student_ids_with_pending_coupon_use_requests = student_ids_with_pending_coupon_use_requests
    @student_ids_with_unread_student_messages = student_ids_with_unread_student_messages

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

  def student_login_qr
    authorize @classroom, :update?

    @student_login_url = public_student_login_url(student_login_token: @classroom.student_login_token)
    @student_login_qr_png_data_url = qr_png_data_url(@student_login_url)
  end

  def download_student_login_qr
    authorize @classroom, :update?

    student_login_url = public_student_login_url(student_login_token: @classroom.student_login_token)
    send_data qr_png_binary(student_login_url),
      type: "image/png",
      disposition: "attachment",
      filename: "student-login-qr-#{@classroom.id}.png"
  end

  def regenerate_student_login_token
    authorize @classroom, :update?

    @classroom.regenerate_student_login_token
    redirect_to edit_classroom_path(@classroom),
      notice: "학생 로그인 주소를 재발급했습니다. 기존에 복사해 둔 주소와 기존 QR 코드는 더 이상 사용할 수 없습니다. 아래 새 주소를 다시 복사하거나 QR 코드를 다시 안내하세요.",
      status: :see_other
  end

  # Turbo로 일간 칭찬왕 영역만 새로고침
  def refresh_compliment_king
    authorize @classroom, :show?
    @enabled_compliment_king_periods = @classroom.enabled_compliment_king_periods
    @selected_period = params[:period].presence || "daily"
    raise ActiveRecord::RecordNotFound unless @enabled_compliment_king_periods.include?(@selected_period)
    @selected_section = build_compliment_king_sections(enabled_periods: @enabled_compliment_king_periods).fetch(@selected_period)
    @issued_winner_ids = build_issued_compliment_king_winner_ids(period: @selected_period, section: @selected_section)

    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom) }
      f.turbo_stream { render :refresh_compliment_king, layout: false } # flash 응답 없음
    end
  end

  def draw_coupon
    authorize @classroom, :draw_coupon?

    basis, mode = normalized_basis_and_mode(params[:basis], params[:mode])
    now = Time.current
    @play_coupon_animation = false
    
    # 0) 사전 검증: target_user_id가 있으면 해당 교실 소속인지 즉시 확인 (fail fast)
    if params[:user_id].present?
      unless ClassroomMembership.exists?(user_id: params[:user_id], classroom_id: @classroom.id)
        message = t("errors.user_not_in_classroom")
        winner = nil
        winner_coupons = nil
        load_recent_issued_coupons!
        respond_to do |f|
          f.html { redirect_to classroom_path(@classroom), alert: message, status: :unprocessable_entity }
          f.turbo_stream do
            flash.now[:alert] = message
            render :draw_coupon, layout: "application", status: :unprocessable_entity,
              locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
          end
          f.json { render json: { ok: false, error: "user_not_in_classroom" }, status: :unprocessable_entity }
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
        classroom_id:   @classroom.id,
        issuance_basis: basis,
        basis_tag:      mode,
        # issued_by_id:   current_user.id # issued_by_id 조건을 빼면 다중 교사 동시 클릭도 소프트 차단
      )
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

      if scope.where("issued_at >= ?", now - DUP_WINDOW).exists?
        message = t("coupons.draw.duplicate")
        load_recent_issued_coupons! 
        respond_to do |f|
          f.html { redirect_to classroom_path(@classroom), alert: message,
            status: :conflict }
          f.turbo_stream do
            flash.now[:alert] = message
            render :draw_coupon, layout: "application", status: :conflict,
              locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
          end
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
        @issued_winner_ids = build_issued_compliment_king_winner_ids(period: @selected_period, section: @selected_section)
      end

    end

    load_recent_issued_coupons! 
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), notice: notice_message, status: :see_other }
      f.turbo_stream do
          flash.now[:notice] = notice_message
          render :draw_coupon, layout: "application",
            locals: {
              winner: winner,
              winner_coupons: winner_coupons,
              winner_recent_issued_coupons: winner_recent_issued_coupons,
              winner_kpi_counts: winner_kpi_counts,
              issued_coupons: @issued_coupons
            }
      end
      f.json do
          render json: { coupon_id: issued.id, title: template.title, user_id: winner.id },
            status: :created
      end
    end

  rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
    # 부분 유니크 인덱스(status=0 & daily)에 걸린 경우
    message = t("coupons.draw.already_issued_today")
    load_recent_issued_coupons!
    respond_to do |f|
      f.html  { redirect_to classroom_path(@classroom), alert: message, status: :conflict }
      f.turbo_stream do
        flash.now[:alert] = message
        render :draw_coupon, layout: "application", status: :conflict,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      f.json  { render json: { ok: false, error: "already_issued_today" }, status: :conflict }
    end

  rescue ActiveRecord::RecordNotFound => e
    message = t("coupons.draw.not_found")
    load_recent_issued_coupons! 
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), alert: message, status: :not_found }
      f.turbo_stream do
        flash.now[:alert] = message
        render layout: "application", status: :not_found,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      f.json { render json: { ok: false, error: "not_found", detail: e.message }, status: :not_found }
    end

  rescue CouponDraw::Issue::Error => e
    message = t(e.i18n_key)
    load_recent_issued_coupons!
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), alert: message, status: e.http_status }

      f.turbo_stream do
        flash.now[:alert] = message
        render :draw_coupon, layout: "application", status: e.http_status,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      f.json { render json: { ok: false, error: "invalid", detail: e.i18n_key }, status: e.http_status }
    end

  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    message = t("coupons.draw.invalid", reason: e.message)
    load_recent_issued_coupons! 
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), alert: message, status: :unprocessable_entity }
      f.turbo_stream do
        flash.now[:alert] = message
        render layout: "application", status: :unprocessable_entity,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      f.json { render json: { ok: false, error: "invalid", detail: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def classroom_params
    params.require(:classroom).permit(
      :name,
      :daily_compliment_king_enabled,
      :weekly_compliment_king_enabled,
      :monthly_compliment_king_enabled,
      :message_policy
    )
  end

  def redirect_students_to_mypage!
    return unless current_user&.student?

    redirect_to user_path(current_user)
  end

  def load_recent_issued_coupons!
    @issued_coupons = policy_scope(UserCoupon).where(classroom_id: @classroom.id)
      .includes(:user, :coupon_template)
      .order(created_at: :desc)
      .limit(5)
      .load
  end

  def student_ids_with_pending_coupon_use_requests
    return Set.new unless @can_manage_classroom

    Set.new(CouponUseRequest
      .pending
      .where(classroom_id: @classroom.id, student_id: @students.select(:id))
      .distinct
      .pluck(:student_id))
  end

  def student_ids_with_unread_student_messages
    return Set.new unless @can_manage_classroom
    return Set.new unless @classroom.student_messages_enabled?

    Set.new(UserMessage
      .unread_student_messages
      .where(classroom_id: @classroom.id, sender_id: @students.select(:id))
      .distinct
      .pluck(:sender_id))
  end

  def qr_png_data_url(text)
    "data:image/png;base64,#{Base64.strict_encode64(qr_png_binary(text))}"
  end

  def qr_png_binary(text)
    RQRCode::QRCode.new(text).as_png(size: 320).to_s
  end

  def build_compliment_king_sections(enabled_periods:)
    Classroom::COMPLIMENT_KING_PERIODS.filter_map do |period|
      next unless enabled_periods.include?(period)

      [period, ComplimentKings::Pick.call(classroom: @classroom, period: period)]
    end.to_h
  end

  def build_compliment_king_period_cards(enabled_periods:)
    enabled_periods.map do |period|
      {
        period: period,
        frame_id: view_context.dom_id(@classroom, :"compliment_king_#{period}")
      }
    end
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
