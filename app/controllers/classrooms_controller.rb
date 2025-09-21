class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom, only: [:show, :edit, :update, :destroy,:refresh_compliment_king]
  # before_action :require_teacher_or_admin!, only: [:new, :create, :edit, :update, :destroy]
  # before_action :authorize_classroom_owner!, only: [:edit, :update, :destroy]

  def index
    @classrooms = policy_scope(Classroom).order(created_at: :desc)
    authorize Classroom
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

  # POST /classrooms/:id/draw_coupon
  def draw_coupon
    @classroom = Classroom.find(params[:id])
    authorize @classroom, :show?  # 보기 권한은 그대로
    return head :forbidden unless current_user&.teacher? || current_user&.admin?

    basis = (params[:basis].presence || "daily").to_s      # "daily" | "weekly" | "manual" | "hybrid"
    mode  = (params[:mode].presence  || "daily_top").to_s  # "daily_top" | "weekly_top" | "accumulated" 등

    period_start = UserCoupon.period_start_for(basis, now: Time.zone.now)

    # 1) 칭찬왕 산정 (기본: 일간/주간 최다)
    winner = pick_winner!(@classroom, basis: basis, mode: mode)
    return render json: { error: "선발할 학생이 없습니다." }, status: :unprocessable_entity unless winner

    # 2) (선택) 학생별 주기 중복 방지: 같은 기준/기간에 이미 발급받았으면 409
    if UserCoupon.for_basis_and_period(basis, period_start)
                .where(user_id: winner.id).exists?
      return render json: { error: "이미 해당 기간에 쿠폰을 발급받았습니다." }, status: :conflict
    end

    # 3) 템플릿 가중 랜덤
    template = CouponTemplate.weighted_pick
    return render json: { error: "활성 쿠폰 템플릿이 없습니다." }, status: :unprocessable_entity unless template

    # 4) 발급
    coupon = UserCoupon.issue!(
      user: winner,
      classroom: @classroom,
      template: template,
      issued_by: current_user,
      issuance_basis: basis,
      period_start_on: period_start,
      basis_tag: mode
    )

    respond_to do |f|
      f.json  { render json: { coupon_id: coupon.id, title: template.title, user_id: winner.id }, status: :created }
      f.turbo_stream
      f.html  { redirect_to classroom_path(@classroom), notice: "#{winner.name}에게 #{template.title} 쿠폰 발급" }
    end
  end

  private

  # basis/mode에 따라 오늘/이번주 칭찬왕 산정
  def pick_winner!(classroom, basis:, mode:)
    case [basis, mode]
    when ["daily", "daily_top"]
      range = Time.zone.today.all_day
      top_receiver_in_range(classroom, range)
    when ["weekly", "weekly_top"]
      start = Time.zone.now.beginning_of_week(:monday)
      range = start..(start.end_of_week(:monday))
      top_receiver_in_range(classroom, range)
    else
      # 임시 기본: 일간 최다
      range = Time.zone.today.all_day
      top_receiver_in_range(classroom, range)
    end
  end

  def top_receiver_in_range(classroom, range)
    counts = Compliment.where(classroom: classroom, given_at: range).group(:receiver_id).count
    return nil if counts.blank?

    max = counts.values.max
    candidate_ids = counts.select { |_, v| v == max }.keys
    classroom.students.where(id: candidate_ids).sample
  end

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def classroom_params
    params.require(:classroom).permit(:name)
  end
end
