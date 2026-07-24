class ComplimentEventsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize Compliment

    @accessible_classrooms = Classroom.accessible_for_compliments(current_user).order(:name)
    @accessible_classroom_ids = @accessible_classrooms.reorder(nil).pluck(:id)
    @classroom_options = [[t("reports.defaults.all_classrooms"), ""]] +
                         @accessible_classrooms.map { |classroom| [classroom.name, classroom.id] }
    @selected_classroom = selected_accessible_classroom
    @invalid_classroom_filter = params[:classroom_id].present? && @selected_classroom.blank?
    @selected_student_membership = selected_student_membership
    @student_filter_disabled = @selected_classroom.blank?
    @student_options = student_filter_options
    @kind = params[:kind].presence_in(%w[all general custom]) || "all"
    @kind_options = [
      [t("compliment_events.index.filters.all_kinds"), "all"],
      [t("compliment_events.index.filters.general"), "general"],
      [t("compliment_events.index.filters.custom"), "custom"]
    ]

    base = policy_scope(Compliment).includes(:classroom, :giver, :receiver)
    base = base.none if @invalid_classroom_filter
    base = base.where(classroom_id: @selected_classroom.id) if @selected_classroom
    base = apply_student_filter(base)
    base = base.where(reason: [nil, ""]) if @kind == "general"
    base = base.where.not(reason: [nil, ""]) if @kind == "custom"

    @summary_total = base.count
    @pagination_params = pagination_params
    @pagy, @compliments = pagy(
      :offset,
      base.order(given_at: :desc, id: :desc),
      limit: 10,
      request: {
        base_url: request.base_url,
        path: compliment_events_path,
        params: @pagination_params.merge("page" => params[:page]).compact
      }
    )
  end

  private

  def selected_accessible_classroom
    return nil if params[:classroom_id].blank?

    @accessible_classrooms.find { |classroom| classroom.id == params[:classroom_id].to_i }
  end

  def selected_student_membership
    return nil unless @selected_classroom
    return nil if params[:student_membership_id].blank?

    ClassroomMembership.student
                       .where(classroom_id: @selected_classroom.id)
                       .find_by(id: params[:student_membership_id])
  end

  def student_filter_options
    if @student_filter_disabled
      return [[t("compliment_events.index.filters.select_classroom_first"), ""]]
    end

    memberships = ClassroomMembership.student
                                     .includes(:user)
                                     .where(classroom_id: @selected_classroom.id)
                                     .order(:created_at, :id)
                                     .to_a
    active_memberships, inactive_memberships = memberships.partition(&:active?)

    [[t("compliment_events.index.filters.all_students"), ""]] +
      (active_memberships + inactive_memberships).map { |membership| [membership.user.name, membership.id] }
  end

  def apply_student_filter(base)
    return base if params[:student_membership_id].blank?
    return base unless @selected_classroom
    return base.none unless @selected_student_membership

    base.where(
      classroom_id: @selected_student_membership.classroom_id,
      receiver_id: @selected_student_membership.user_id
    )
  end

  def pagination_params
    {}.tap do |query|
      query["classroom_id"] = @selected_classroom.id.to_s if @selected_classroom
      query["student_membership_id"] = @selected_student_membership.id.to_s if @selected_student_membership
      query["kind"] = @kind if @kind != "all"
    end
  end
end
