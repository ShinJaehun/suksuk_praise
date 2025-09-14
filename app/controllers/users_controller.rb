class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show]

    #def index
        #@students = User.student
    #end

    def show
      @classroom = Classroom.find_by(id: params[:classroom_id])
      authorize @classroom, :show? if @classroom

      @compliments = @user.received_compliments
                          .includes(:giver, :classroom)
                          .order(given_at: :desc)
      @compliments = @compliments.where(classroom_id: @classroom.id) if @classroom
    end

    private

    def set_user
        @user = User.find(params[:id])
    end

end
