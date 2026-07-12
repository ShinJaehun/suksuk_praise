class SchoolsController < ApplicationController
  before_action :authenticate_user!

  def show
    @school = policy_scope(School).find(params[:id])
    authorize @school, :show?

    @classroom_count = @school.classrooms.count
    @teacher_count = @school.school_memberships.count
    @managers = @school.school_memberships.manager.includes(:user).map(&:user)
    @school_closures = @school.school_closures.order(starts_on: :asc, ends_on: :asc, id: :asc)
    @can_manage_operations = policy(@school).manage_operations?
  end
end
