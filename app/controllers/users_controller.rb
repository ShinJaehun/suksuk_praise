class UsersController < ApplicationController
  include UserShowDataLoader

  before_action :authenticate_user!
  before_action :set_user, only: [:show, :destroy]
  before_action :set_managed_page_context!, only: [:destroy]

  def show
    # 0) 교실 컨텍스트 로드(있는 경우만)
    if params[:classroom_id].present?
      @classroom = load_and_authorize_classroom!(params[:classroom_id])
      ensure_membership_for_user_in_classroom!(@user, @classroom)
    end

    # 1) 사용자 페이지 접근 권한
    authorize @user, :show?
    redirect_to_managed_student_page! and return

    set_page_context!
    @can_create_compliment = @managed_page && policy(@classroom).create_compliment?
    @can_draw_coupon = @managed_page && policy(@classroom).draw_coupon?
    @visible_classrooms = @self_page ? @user.classrooms.order(created_at: :asc) : []

    load_user_show_data!(
      user: @user,
      classroom: @classroom,
      include_recent_issued: true,
      recent_in_classroom: true
    )
  end

  def destroy
    authorize @user, :destroy_student?

    @user.destroy!
    redirect_to classroom_path(@classroom), notice: "학생 계정을 삭제했습니다.", status: :see_other
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_page_context!
    @self_page = params[:classroom_id].blank? && current_user == @user
    @managed_page = params[:classroom_id].present?
    @can_destroy_student = @managed_page && Pundit.policy!(current_user, @user).destroy_student?
  end

  def redirect_to_managed_student_page!
    return if params[:classroom_id].present?
    return unless @user.student?
    return if current_user == @user

    classroom = managed_page_classroom_for(@user)
    raise ActiveRecord::RecordNotFound unless classroom

    redirect_to classroom_user_path(classroom, @user)
  end

  def managed_page_classroom_for(user)
    return user.classrooms.order(created_at: :asc).first if current_user.admin?
    return teacher_managed_classroom_for(user) if current_user.teacher?

    nil
  end

  def teacher_managed_classroom_for(user)
    Classroom
      .joins(:classroom_memberships)
      .where(classroom_memberships: { user_id: current_user.id, role: "teacher" })
      .where(id: user.classroom_ids)
      .order(created_at: :asc)
      .first
  end

  # classroom_id가 들어왔는데 없거나 권한이 없으면 명확히 실패시킴
  def load_and_authorize_classroom!(cid)
    classroom = Classroom.find(cid) # 못 찾으면 ActiveRecord::RecordNotFound
    authorize classroom, :show?
    classroom
  end

  def set_managed_page_context!
    @classroom = load_and_authorize_classroom!(params[:classroom_id])
    ensure_membership_for_user_in_classroom!(@user, @classroom)
  end

  # ---- 가드레일 핵심: 상세 대상(@user)이 해당 교실의 '실제 멤버'인지 확인 ----
  def ensure_membership_for_user_in_classroom!(user, classroom)
    is_member = classroom.classroom_memberships.exists?(user_id: user.id)
    raise ActiveRecord::RecordNotFound unless is_member
  end
end
