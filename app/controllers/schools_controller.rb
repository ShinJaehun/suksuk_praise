class SchoolsController < ApplicationController
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

    @classroom_count = @school.classrooms.count
    @teacher_count = @school.school_memberships.count
    @managers = @school.school_memberships.manager.includes(:user).map(&:user)
    @school_closures = @school.school_closures.order(starts_on: :asc, ends_on: :asc, id: :asc)
    @can_manage_operations = policy(@school).manage_operations?
    @classrooms = @school.classrooms.includes(classroom_memberships: :user).order(:name, :id)
    @teacher_memberships = @school.school_memberships.includes(user: { classroom_memberships: :classroom }).order(:role, :id)
    if current_user.admin?
      @manager_candidates = User.teacher
        .left_joins(:school_membership)
        .where(school_memberships: { id: nil })
        .or(User.teacher.left_joins(:school_membership).where(school_memberships: { school_id: @school.id, role: :member }))
        .order(:name, :id)
    end
  end
end
