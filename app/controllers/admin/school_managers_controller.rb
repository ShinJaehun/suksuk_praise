module Admin
  class SchoolManagersController < Admin::BaseController
    before_action :set_school
    before_action :authorize_admin

    def create
      membership = @school.school_memberships.includes(:user).find_by!(user_id: params.require(:user_id))
      raise ActiveRecord::RecordNotFound unless membership.user.teacher?

      if membership.update(role: :manager)
        render_manager_success("admin.school_managers.create.success")
      else
        redirect_to edit_school_path(@school),
          alert: membership.errors.full_messages.to_sentence,
          status: :see_other
      end
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
      authorize @school, :manage_operations?
    end

    def render_manager_success(message_key)
      redirect_to edit_school_path(@school),
        notice: t(message_key),
        status: :see_other
    end
  end
end
