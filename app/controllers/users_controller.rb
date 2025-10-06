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

        # 2) policy_scope로 권한과 쿼리 범위 정렬
        @compliments = policy_scope(Compliment)
            .where(receiver_id: @user.id)
        @compliments = @compliments.where(classroom_id: @classroom.id) if @classroom
        @compliments = @compliments
            .includes(:giver, :classroom)
            .order(given_at: :desc)
        
        @coupons = policy_scope(UserCoupon)
            .where(user_id: @user.id, classroom_id: @classroom.id, status: "issued")
            .includes(:coupon_template)
            .order(created_at: :desc)
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
