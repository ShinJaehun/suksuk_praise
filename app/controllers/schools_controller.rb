class SchoolsController < ApplicationController
  include SchoolWorkspacePrepareable

  before_action :authenticate_user!

  def index
    @schools = policy_scope(School).order(:name, :id).load
    authorize School

    redirect_to school_path(@schools.first) and return if current_user.teacher? && @schools.one?

    school_ids = @schools.map(&:id)
    @classroom_counts = Classroom.where(school_id: school_ids).group(:school_id).count
    @teacher_counts = SchoolMembership.where(school_id: school_ids).group(:school_id).count
    @managers_by_school_id = SchoolMembership.manager.includes(:user).where(school_id: school_ids).group_by(&:school_id)
  end

  def show
    @school = policy_scope(School).find(params[:id])
    authorize @school, :show?

    @school_closure = @school.school_closures.new
    prepare_school_workspace
  end
end
