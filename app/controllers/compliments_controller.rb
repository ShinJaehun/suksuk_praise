class ComplimentsController < ApplicationController
  include UserShowDataLoader

  before_action :authenticate_user!
  before_action :set_classroom

  DUP_WINDOW = 1.second

  def create
    authorize @classroom, :show?
    authorize @classroom, :create_compliment?
    
    @receiver = @classroom.classroom_memberships.find_by!(user_id: compliment_params[:receiver_id]).user

    now = Time.current

    @classroom.with_lock do
      if Compliment.where(
           classroom_id: @classroom.id,
           giver_id:     current_user.id,
           receiver_id:  @receiver.id
         ).where("given_at >= ?", now - DUP_WINDOW).exists?

        load_user_show_data!(
          user: @receiver,
          classroom: @classroom,
          include_recent_issued: false,
          recent_in_classroom: true
        )
        message = t("compliments.create.duplicate")
        return respond_to do |f|
          f.html { redirect_back fallback_location: user_path(@receiver, classroom_id: @classroom.id),
            alert: message, status: :conflict }
          f.turbo_stream do
            flash.now[:alert] = message
            render :create, layout: "application", status: :conflict 
          end
          f.json { render json: { ok: false, error: "duplicate_request" }, status: :conflict }
        end
      end

      ApplicationRecord.transaction(requires_new: true) do
        @created_compliment = Compliment.create!(
          classroom_id: @classroom.id,
          giver_id:     current_user.id,
          receiver_id:  @receiver.id,
          given_at:     now
        )
        @receiver.increment!(:points)
      end
    end

    load_user_show_data!(
      user: @receiver,
      classroom: @classroom,
      include_recent_issued: false,
      recent_in_classroom: true
    )

    respond_to do |f|
      f.html { redirect_to user_path(@receiver, classroom_id: @classroom.id), status: :see_other }
      f.turbo_stream { render :create, layout: "application" }
      f.json { render json: { ok: true, receiver_id: @receiver.id }, status: :created }
    end

  rescue ActiveRecord::RecordInvalid => e
    load_user_show_data!(
      user: @receiver,
      classroom: @classroom,
      include_recent_issued: false,
      recent_in_classroom: true
    ) if defined?(@receiver) && @receiver.present?
    message =  t("compliments.create.failure", detail: e.message) 
    respond_to do |f|
      f.html { redirect_back fallback_location: user_path(@receiver, classroom_id: @classroom.id),
        alert: message, status: :unprocessable_entity }
      f.turbo_stream do
        flash.now[:alert] = message
        render layout: "application", status: :unprocessable_entity 
      end
      f.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
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
