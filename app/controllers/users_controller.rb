class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show, :compliment]

    #def index
        #@students = User.student
    #end

    def show
      @compliments = @user.received_compliments.includes(:giver, :classroom).order(given_at: :desc)
    end

    def compliment
      @classroom = Classroom.find(params[:classroom_id]) if params[:classroom_id]
      unless current_user.teacher? || current_user.admin?
        head :forbidden and return
      end

      @user.increment!(:points)

      Compliment.create!(
        giver_id: current_user.id,
        receiver_id: @user.id,
        classroom_id: @classroom&.id,
        given_at: Time.current
      )

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to request.referer || root_path, notice: "칭찬 완료!"}
      end
    end

    private

    def set_user
        @user = User.find(params[:id])
    end
end
