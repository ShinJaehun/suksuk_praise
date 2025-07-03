class UsersController < ApplicationController
    before_action :authenticate_user!, except: [:show]
    before_action :set_user, only: [:show, :compliment]

    def index
        @students = User.student
    end

    def show

    end

    def compliment
        if current_user.teacher? || current_user.admin?
            @user.increment!(:points)
            respond_to do |format|
                format.turbo_stream
                format.html { redirect_to root_path, notice: "칭찬 완료!"}
            end
        else
            head :forbidden
        end
    end

    private

    def set_user
        @user = User.find(params[:id])
    end
end