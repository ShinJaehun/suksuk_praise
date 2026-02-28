class UsersController < ApplicationController
    include UserShowDataLoader

    before_action :authenticate_user!
    before_action :set_user, only: [:show]

    def show
        # 0) 교실 컨텍스트 로드(있는 경우만)
        if params[:classroom_id].present?
            @classroom = load_and_authorize_classroom!(params[:classroom_id])
            ensure_membership_for_user_in_classroom!(@user, @classroom)
        end

        # 1) 사용자 페이지 접근 권한
        authorize @user, :show?
        @can_create_compliment = @classroom.present? && policy(@classroom).create_compliment?

        load_user_show_data!(
            user: @user,
            classroom: @classroom,
            include_recent_issued: true,
            recent_in_classroom: false
        )
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
        is_member = classroom.classroom_memberships.exists?(user_id: user.id)
        raise ActiveRecord::RecordNotFound unless is_member
    end
end
