class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show, :compliment]
    before_action :set_classroom, only: [:compliment]

    #def index
        #@students = User.student
    #end

    def show
      compliments = @user.received_compliments.includes(:giver, :classroom).order(given_at: :desc)
      @compliments = policy_scope(compliments)
    end

    def compliment
      # @classroom = Classroom.find(params[:classroom_id]) if params[:classroom_id]
      # unless current_user.teacher? || current_user.admin?
      #   head :forbidden and return
      # end

      # @user.increment!(:points)

      # Compliment.create!(
      #   giver_id: current_user.id,
      #   receiver_id: @user.id,
      #   classroom_id: @classroom&.id,
      #   given_at: Time.current
      # )

      # respond_to do |format|
      #   format.turbo_stream
      #   format.html { redirect_to request.referer || root_path, notice: "칭찬 완료!"}
      # end
      
      return head :unprocessable_entity unless @classroom.present?
      
      @compliment = Compliment.new(
        giver: current_user,
        receiver: @user,
        classroom: @classroom,
        given_at: Time.current
      )

      authorize @compliment, :create?

      ApplicationRecord.transaction do
        @compliment.save!
        @user.increment!(:points)
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to request.referer || root_path, notice: "칭찬 완료!" }
      end

    rescue Pundit::NotAuthorizedError
      head :forbidden

    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.turbo_stream { 
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: e.record.errors.full_messages.to_sentence }), status: :unprocessable_entity }
        format.html { redirect_to(request.referer || root_path,
          alert: e.record.errors.full_messages.to_sentence) }
      end
    end

    private

    def set_user
        @user = User.find(params[:id])
    end

    def set_classroom
      @classroom = Classroom.find_by(id: params[:classroom_id])
    end
end
