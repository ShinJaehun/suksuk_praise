class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show]

    #def index
        #@students = User.student
    #end

    def show
        @classroom = load_and_authorize_classroom!(params[:classroom_id]) if params[:classroom_id].present?

        # 1) 사용자 페이지 접근 권한
        authorize @user, :show?

        # 2) policy_scope로 권한과 쿼리 범위 정렬
        @compliments = policy_scope(Compliment)
                        .where(receiver_id: @user.id)
        @compliments = @compliments.where(classroom_id: @classroom.id) if @classroom

        @compliments = @compliments
                        .includes(:giver, :classroom)
                        .order(given_at: :desc)
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
end
