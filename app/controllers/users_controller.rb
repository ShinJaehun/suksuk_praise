class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show]

    def show
        # @classroom = load_and_authorize_classroom!(params[:classroom_id]) if params[:classroom_id].present?

        # 0) 교실 컨텍스트 로드(있는 경우만)
        if params[:classroom_id].present?
            # 현재 로그인 유저의 교실 접근 권한 확인
            @classroom = load_and_authorize_classroom!(params[:classroom_id])
            # 상세 대상(@user)이 그 교실 멤버인지 검증(아니면 404)
            ensure_membership_for_user_in_classroom!(@user, @classroom)
        end

        # 1) 사용자 페이지 접근 권한
        authorize @user, :show?
        @can_create_compliment = @classroom.present? && policy(@classroom).create_compliment?

        # 2) 칭찬 쿼리(공통 scope) + KPI
        compliments_scope = policy_scope(Compliment).where(receiver_id: @user.id)
        compliments_scope = compliments_scope.where(classroom_id: @classroom.id) if @classroom

        @today_compliments_count = compliments_scope.where(given_at: Time.zone.today.all_day).count
        @compliments = compliments_scope.includes(:giver, :classroom).order(given_at: :desc)

        # 3) 쿠폰 쿼리(공통 scope) + KPI
        coupons_scope = policy_scope(UserCoupon).where(user_id: @user.id)
        coupons_scope = coupons_scope.where(classroom_id: @classroom.id) if @classroom

        @coupons = coupons_scope
            .where(status: "issued")
            .includes(:coupon_template)
            .order(issued_at: :desc)

        @today_issued_coupons_count = coupons_scope.where(issued_at: Time.zone.today.all_day).count
        @used_coupons_count = coupons_scope.where(status: "used").count
        @kpi_counts = {
            points: @user.points,
            today_compliments: @today_compliments_count,
            issued_count: @coupons.size,
            today_issued_coupons: @today_issued_coupons_count,
            used_coupons: @used_coupons_count
        }

        @recent_issued_coupons = policy_scope(UserCoupon)
            .where(user_id: @user.id)
            .includes(:coupon_template, :user)
            .order(issued_at: :desc)
            .limit(10)
    end

    private

    def set_user
        @user = User.find(params[:id])
    end
    
    # classroom_id가 들어왔는데 없거나 권한이 없으면 명확히 실패시킴
    def load_and_authorize_classroom!(cid)
        classroom = Classroom.find(cid) # 못 찾으면 ActiveRecord::RecordNotFound
        authorize classroom, :show?
        classroom
    end

    # ---- 가드레일 핵심: 상세 대상(@user)이 해당 교실의 '실제 멤버'인지 확인 ----
    def ensure_membership_for_user_in_classroom!(user, classroom)
        # 연관이 있다면 classroom.users.exists?(user.id) 로도 가능
        is_member = classroom.classroom_memberships.exists?(user_id: user.id)
        raise ActiveRecord::RecordNotFound unless is_member
    end
end
