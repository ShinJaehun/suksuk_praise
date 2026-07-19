module Admin
  class SchoolManagersController < ApplicationController
    include SchoolWorkspacePrepareable

    before_action :authenticate_user!
    before_action :set_school
    before_action :authorize_admin

    def create
      membership = @school.school_memberships.includes(:user).find_by!(user_id: params.require(:user_id))
      raise ActiveRecord::RecordNotFound unless membership.user.teacher?

      membership.update!(role: :manager)
      render_manager_success("admin.school_managers.create.success")
    end

    def destroy
      membership = @school.school_memberships.manager.find_by!(user_id: params[:user_id])
      membership.update!(role: :member)
      render_manager_success("admin.school_managers.destroy.success")
    end

    private

    def set_school
      @school = School.find(params[:school_id])
    end

    def authorize_admin
      authorize @school, :update?
    end

    def render_manager_success(message_key)
      prepare_school_overview

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "school_overview",
              partial: "schools/overview",
              locals: {
                school: @school,
                classroom_count: @classroom_count,
                teacher_count: @teacher_count,
                managers: @managers
              }
            ),
            turbo_stream.update("modal", "")
          ]
        end
        format.html do
          redirect_to school_path(@school),
            notice: t(message_key),
            status: :see_other
        end
      end
    end
  end
end
