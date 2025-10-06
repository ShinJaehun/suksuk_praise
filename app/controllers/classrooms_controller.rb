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
      redirect_to classroom_path(@classroom), notice: "교실이 생성되었습니다."
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
      redirect_to @classroom, notice: "교실 이름이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @classroom
    @classroom.destroy
    redirect_to classrooms_path, notice: "교실이 삭제되었습니다."
  end

  # Turbo로 일간 칭찬왕 영역만 새로고침
  def refresh_compliment_king
    authorize @classroom, :show?
    @students = @classroom.students
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

    respond_to { |f| f.turbo_stream }
  end

  def draw_coupon
    authorize @classroom, :draw_coupon?

    basis = (params[:basis].presence || "daily").to_s   # "daily" | "weekly" | ...
    mode  = (params[:mode].presence  || "daily_top").to_s

    # target_user_id가 있으면 그 학생에게 수동 발급, 없으면 서비스 내부에서 pick 수행
    coupon = CouponDraw::Issue.call(
      classroom: @classroom,
      basis: basis,
      mode: mode,
      issued_by: current_user,
      target_user_id: params[:user_id]
    )

    winner   = coupon.user
    template = coupon.coupon_template # UserCoupon.issue!(..., template: ...) 구조를 그대로 가정

    flash.now[:notice] = "#{winner.name}에게 #{template.title} 쿠폰 발급"

    respond_to do |f|
      f.turbo_stream # app/views/classrooms/draw_coupon.turbo_stream.erb
      f.html { redirect_to classroom_path(@classroom), notice: "#{winner.name}에게 #{template.title} 쿠폰 발급" }
      f.json { render json: { coupon_id: coupon.id, title: template.title, user_id: winner.id }, status: :created }
    end
  rescue ActiveRecord::RecordNotFound => e
    respond_to do |f|
      f.turbo_stream { flash.now[:alert] = "대상 정보를 찾을 수 없습니다." }
      f.html { redirect_to classroom_path(@classroom), alert: "대상 정보를 찾을 수 없습니다." }
      f.json { render json: { ok: false, error: "not_found", detail: e.message }, status: :not_found }
    end
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    respond_to do |f|
      f.turbo_stream { flash.now[:alert] = "발급에 실패했습니다: #{e.message}" }
      f.html { redirect_to classroom_path(@classroom), alert: "발급에 실패했습니다: #{e.message}" }
      f.json { render json: { ok: false, error: "invalid", detail: e.message }, status: :unprocessable_entity }
    end
  rescue StandardError => e
    # 예: 기간 중복/템플릿 없음 등 서비스에서 커스텀 예외를 올린 경우
    respond_to do |f|
      f.turbo_stream { flash.now[:alert] = e.message }
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
end
