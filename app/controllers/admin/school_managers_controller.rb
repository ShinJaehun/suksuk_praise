module Admin
  class SchoolManagersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_school
    before_action :authorize_admin

    def create
      teacher = User.teacher.find(params.require(:user_id))
      membership = teacher.school_membership

      if membership && membership.school_id != @school.id
        redirect_to school_path(@school), alert: t("admin.school_managers.membership_conflict")
      else
        membership ||= @school.school_memberships.build(user: teacher)
        membership.update!(role: :manager)
        redirect_to school_path(@school), notice: t("admin.school_managers.create.success")
      end
    end

    def destroy
      membership = @school.school_memberships.manager.find_by!(user_id: params[:user_id])
      membership.update!(role: :member)
      redirect_to school_path(@school), notice: t("admin.school_managers.destroy.success"), status: :see_other
    end

    private

    def set_school
      @school = School.find(params[:school_id])
    end

    def authorize_admin
      authorize @school, :update?
    end
  end
end
