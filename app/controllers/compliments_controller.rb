class ComplimentsController < ApplicationController
  include UserShowDataLoader

  before_action :authenticate_user!
  before_action :set_classroom, only: %i[new create]

  DUP_WINDOW = 1.second

  def index
    authorize Compliment

    @accessible_classrooms = Classroom.accessible_for_compliments(current_user).order(:name)
    @accessible_classroom_ids = @accessible_classrooms.reorder(nil).pluck(:id)
    @classroom_options = [[t("reports.defaults.all_classrooms", default: "전체 교실"), ""]] +
                         @accessible_classrooms.map { |classroom| [classroom.name, classroom.id] }
    @selected_classroom = selected_accessible_classroom
    @invalid_classroom_filter = params[:classroom_id].present? && @selected_classroom.blank?
    @student_options = student_filter_options
    @kind = params[:kind].presence_in(%w[all general custom]) || "all"
    @kind_options = [
      [t("compliments.index.filters.all_kinds"), "all"],
      [t("compliments.index.filters.general"), "general"],
      [t("compliments.index.filters.custom"), "custom"]
    ]

    base = policy_scope(Compliment).includes(:classroom, :giver, :receiver)
    base = base.none if @invalid_classroom_filter
    base = base.where(classroom_id: @selected_classroom.id) if @selected_classroom
    base = base.where(id: selected_student_compliment_scope) if params[:student_membership_id].present?
    base = base.where(reason: [nil, ""]) if @kind == "general"
    base = base.where.not(reason: [nil, ""]) if @kind == "custom"

    @summary_total = base.count
    @pagy, @compliments = pagy(:offset, base.order(given_at: :desc, id: :desc), limit: 10)
  end

  def new
    authorize @classroom, :show?
    authorize @classroom, :create_compliment?

    @receiver = @classroom.classroom_memberships.find_by!(
      user_id: compliment_params[:receiver_id],
      role: "student",
      status: "active"
    ).user
    @compliment_presets = active_compliment_presets

    render layout: false if turbo_frame_request?
  end

  def create
    authorize @classroom, :show?
    authorize @classroom, :create_compliment?

    @receiver = @classroom.classroom_memberships.find_by!(
      user_id: compliment_params[:receiver_id],
      role: "student",
      status: "active"
    ).user

    now = Time.current
    @compliment_preset = find_compliment_preset
    reason = @compliment_preset&.title

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
        load_today_compliment_count_for_receiver
        load_active_compliment_presets
        message = t("compliments.create.duplicate")
        return respond_to do |f|
          f.html { redirect_back fallback_location: classroom_student_path(@classroom, @receiver),
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
          given_at:     now,
          compliment_preset: @compliment_preset,
          reason: reason
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
    load_today_compliment_count_for_receiver
    load_active_compliment_presets

    respond_to do |f|
      f.html { redirect_to classroom_student_path(@classroom, @receiver), status: :see_other }
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
    message = t("compliments.create.failure", detail: e.message)
    respond_to do |f|
      f.html { redirect_back fallback_location: classroom_student_path(@classroom, @receiver),
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
    params.require(:compliment).permit(:receiver_id, :compliment_preset_id)
  end

  def active_compliment_presets
    current_user.compliment_presets.active.ordered
  end

  def selected_accessible_classroom
    return nil if params[:classroom_id].blank?

    @accessible_classrooms.find { |classroom| classroom.id == params[:classroom_id].to_i }
  end

  def student_filter_options
    scope = ClassroomMembership.student.includes(:classroom, :user)
                               .where(classroom_id: @accessible_classroom_ids)
    scope = scope.where(classroom_id: @selected_classroom.id) if @selected_classroom

    memberships = scope.order(:created_at, :id).to_a
    active_memberships, inactive_memberships = memberships.partition(&:active?)

    [[t("compliments.index.filters.all_students"), ""]] +
      (active_memberships + inactive_memberships).map do |membership|
        label = if @selected_classroom
                  membership.user.name
                else
                  t("compliments.index.filters.student_with_classroom",
                    classroom: membership.classroom.name,
                    student: membership.user.name)
                end

        [label, membership.id]
      end
  end

  def selected_student_compliment_scope
    membership = ClassroomMembership.student
                                    .where(classroom_id: @accessible_classroom_ids)
                                    .find_by(id: params[:student_membership_id])
    return Compliment.none.select(:id) unless membership

    Compliment.where(classroom_id: membership.classroom_id, receiver_id: membership.user_id).select(:id)
  end

  def load_active_compliment_presets
    @active_compliment_presets = active_compliment_presets
  end

  def find_compliment_preset
    return nil if compliment_params[:compliment_preset_id].blank?

    active_compliment_presets.find(compliment_params[:compliment_preset_id])
  end

  def load_today_compliment_count_for_receiver
    @today_compliment_count_for_receiver = Compliment.where(
      classroom_id: @classroom.id,
      receiver_id: @receiver.id,
      given_at: Time.zone.today.all_day
    ).count
  end
end
