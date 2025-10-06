class ComplimentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom

  # def create
  #   # 1) 교실 접근 가능? (admin or member) -> show?
  #   authorize @classroom, :show?
  #   # 2) 칭찬 권한? (admin or teacher_of?) -> create_compliment?
  #   authorize @classroom, :create_compliment?

  #   receiver_membership = @classroom.classroom_memberships.find_by!(user_id: compliment_params[:receiver_id])
  #   receiver = receiver_membership.user

  #   compliment = Compliment.new(
  #     classroom_id: @classroom.id,
  #     giver_id: current_user.id,
  #     receiver_id: receiver.id,
  #     given_at: Time.current
  #   )

  #   if compliment.save
  #     redirect_to user_path(receiver, classroom_id: @classroom.id), notice: "칭찬했습니다!"
  #   else
  #     redirect_back fallback_location: user_path(receiver, classroom_id: @classroom.id), alert: "칭찬에 실패했습니다."
  #   end
  # end

  def create
    # 1) 교실 접근 가능? (admin or member) -> show?
    authorize @classroom, :show?
    # 2) 칭찬 권한? (admin or teacher_of?) -> create_compliment?
    authorize @classroom, :create_compliment?
    
    @receiver = @classroom.classroom_memberships.find_by!(user_id: compliment_params[:receiver_id]).user
    
    ApplicationRecord.transaction do

      Compliment.create!(
        classroom_id: @classroom.id,
        giver_id: current_user.id, 
        receiver_id: @receiver.id, 
        given_at: Time.current
      )

      @receiver.increment!(:points)

    end
    
    respond_to do |format|
      # app/views/compliments/create.turbo_stream.erb
      format.turbo_stream   
      format.html { redirect_to user_path(@receiver, classroom_id: @classroom.id), status: :see_other }
      format.json { render json: { ok: true, receiver_id: @receiver.id }, status: :created }
    end

  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.turbo_stream { flash.now[:alert] = "칭찬에 실패했습니다: #{e.message}" }
      format.html { redirect_back fallback_location: user_path(@receiver, classroom_id: @classroom.id), alert: "칭찬에 실패했습니다: #{e.message}" }
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
    end

  end
  
  private

  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def compliment_params
    params.require(:compliment).permit(:receiver_id)
  end
end