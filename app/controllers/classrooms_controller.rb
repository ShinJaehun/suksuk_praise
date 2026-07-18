# app/controllers/classrooms_controller.rb
require "base64"
require "set"

class ClassroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_students_to_mypage!, only: [:index, :show]
  before_action :set_classroom, only: [
    :show, :edit, :update, :destroy, :refresh_compliment_king, :draw_coupon, :student_login_info, :student_login_qr, :download_student_login_qr, :regenerate_student_login_token
  ]
  
  # 더블클릭/중복요청 소프트 가드(2초)
  DUP_WINDOW = 2.seconds

  def index
    # index는 policy_scope만 요구(verify_policy_scoped 훅 통과)
    prepare_school_filter if current_user.admin?
    classrooms_scope = policy_scope(Classroom)
    classrooms_scope = classrooms_scope.where(school_id: @selected_school.id) if current_user.admin? && @selected_school
    @classrooms = classrooms_scope.includes(:school).order(created_at: :desc)
    @classrooms_index_title = t(classrooms_index_title_key)
    classroom_ids = @classrooms.map(&:id)
    teacher_memberships = ClassroomMembership
      .joins(:user)
      .where(classroom_id: classroom_ids, role: "teacher", users: { role: "teacher" })
    @classroom_teacher_counts = teacher_memberships.group(:classroom_id).count
    @classroom_teacher_previews = classroom_membership_previews(classroom_ids, role: "teacher", user_role: "teacher", limit_per_classroom: 1)
    @classroom_student_counts = ClassroomMembership.where(classroom_id: classroom_ids, role: "student").group(:classroom_id).count
    @classroom_student_previews = classroom_membership_previews(classroom_ids, role: "student", limit_per_classroom: 5)
    @manageable_classroom_ids =
      if current_user.admin?
        classroom_ids.to_set
      elsif current_user_school_manager?
        classroom_ids.to_set
      elsif current_user.teacher?
        current_user.classroom_memberships.where(role: "teacher", classroom_id: classroom_ids).pluck(:classroom_id).to_set
      else
        Set.new
      end
    # authorize Classroom  # <- 불필요 (after_action에서 index는 verify_authorized 제외)
  end

  def show
    authorize @classroom
    @can_manage_classroom = policy(@classroom).update?
    @can_manage_classroom_members = policy(@classroom).manage_members?
    @can_refresh_compliment_king = policy(@classroom).refresh_compliment_king?
    @students = @classroom.students.order(created_at: :asc)
    @homeroom_teachers = User.teacher
      .joins(:classroom_memberships)
      .where(classroom_memberships: { classroom_id: @classroom.id, role: "teacher" })
      .with_attached_avatar
      .order(:name, :id)
    @enabled_compliment_king_periods = @classroom.enabled_compliment_king_periods
    @refreshable_compliment_king_periods = refreshable_compliment_king_periods(@enabled_compliment_king_periods)
    @compliment_king_sections = build_compliment_king_sections(enabled_periods: @enabled_compliment_king_periods)
    @compliment_king_period_cards = build_compliment_king_period_cards(enabled_periods: @enabled_compliment_king_periods)
    @student_ids_with_pending_coupon_use_requests = student_ids_with_pending_coupon_use_requests
    @student_ids_with_unread_student_messages = student_ids_with_unread_student_messages
    @today_compliment_counts_by_student_id = Compliment
      .where(
        classroom_id: @classroom.id,
        receiver_id: @students.select(:id),
        given_at: Time.zone.today.all_day
      )
      .group(:receiver_id)
      .count

    load_recent_issued_coupons!
  end

  def new
    authorize Classroom
    @classroom = Classroom.new
    prepare_classroom_form
    if current_user_school_manager?
      @classroom.school = current_user.school_membership.school
    elsif current_user.admin?
      load_school_options
    end
  end

  def create
    authorize Classroom
    @classroom = Classroom.new(classroom_params)
    assign_manager_school
    if create_classroom_with_teacher_assignments
      redirect_to classroom_path(@classroom), notice: t("classrooms.create.success")
    else
      prepare_classroom_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @classroom
    prepare_classroom_form
  end

  def update
    authorize @classroom
    if update_classroom_with_teacher_assignments
      redirect_to @classroom, notice: t("classrooms.update.success")
    else
      prepare_classroom_form
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @classroom

    if @classroom.destroy
      redirect_to classrooms_path,
        notice: t("classrooms.destroy.success"),
        status: :see_other
    else
      redirect_to edit_classroom_path(@classroom),
        alert: classroom_destroy_error_message,
        status: :see_other
    end
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
    redirect_to edit_classroom_path(@classroom),
      alert: t("classrooms.destroy.failure"),
      status: :see_other
  end

  def student_login_info
    authorize @classroom, :manage_members?

    @student_login_url = public_student_login_url(student_login_token: @classroom.student_login_token)
  end

  def student_login_qr
    authorize @classroom, :manage_members?

    @student_login_url = public_student_login_url(student_login_token: @classroom.student_login_token)
    @student_login_qr_png_data_url = qr_png_data_url(@student_login_url)
  end

  def download_student_login_qr
    authorize @classroom, :manage_members?

    student_login_url = public_student_login_url(student_login_token: @classroom.student_login_token)
    send_data qr_png_binary(student_login_url),
      type: "image/png",
      disposition: "attachment",
      filename: "student-login-qr-#{@classroom.id}.png"
  end

  def regenerate_student_login_token
    authorize @classroom, :manage_members?

    @classroom.regenerate_student_login_token
    redirect_to classroom_path(@classroom),
      notice: "학생 로그인 주소를 재발급했습니다. 기존에 복사해 둔 주소와 기존 QR 코드는 더 이상 사용할 수 없습니다. 아래 새 주소를 다시 복사하거나 QR 코드를 다시 안내하세요.",
      status: :see_other
  end

  # Turbo로 일간 칭찬왕 영역만 새로고침
  def refresh_compliment_king
    authorize @classroom, :refresh_compliment_king?
    @enabled_compliment_king_periods = @classroom.enabled_compliment_king_periods
    @selected_period = params[:period].presence || "daily"
    raise ActiveRecord::RecordNotFound unless @enabled_compliment_king_periods.include?(@selected_period)
    unless @classroom.compliment_king_refresh_available_for?(@selected_period)
      respond_to do |f|
        f.html { redirect_to classroom_path(@classroom) }
        f.turbo_stream { redirect_to classroom_path(@classroom) }
        f.json { head :forbidden }
      end
      return
    end

    @selected_section = build_compliment_king_sections(enabled_periods: @enabled_compliment_king_periods).fetch(@selected_period)
    @issued_winner_ids = build_issued_compliment_king_winner_ids(period: @selected_period, section: @selected_section)

    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom) }
      f.turbo_stream { render :refresh_compliment_king, layout: false } # flash 응답 없음
    end
  end

  def draw_coupon
    authorize @classroom, :draw_coupon?

    basis, mode = normalized_basis_and_mode(params[:basis], params[:mode])
    now = Time.current
    @play_coupon_animation = false
    
    # 0) 사전 검증: target_user_id가 있으면 해당 교실 소속인지 즉시 확인 (fail fast)
    if params[:user_id].present?
      unless ClassroomMembership.exists?(
        user_id: params[:user_id],
        classroom_id: @classroom.id,
        role: "student",
        status: "active"
      )
        message = t("errors.user_not_in_classroom")
        winner = nil
        winner_coupons = nil
        load_recent_issued_coupons!
        respond_to do |f|
          f.html { redirect_to classroom_path(@classroom), alert: message, status: :unprocessable_entity }
          f.turbo_stream do
            flash.now[:alert] = message
            render :draw_coupon, layout: "application", status: :unprocessable_entity,
              locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
          end
          f.json { render json: { ok: false, error: "user_not_in_classroom" }, status: :unprocessable_entity }
        end
        return
      end
    end

    issued = nil
    winner = nil
    template = nil
    winner_coupons = nil
    winner_recent_issued_coupons = nil
    winner_kpi_counts = nil
    notice_message = nil

    @classroom.with_lock do

      scope = UserCoupon.where(
        classroom_id:   @classroom.id,
        issuance_basis: basis,
        basis_tag:      mode,
        # issued_by_id:   current_user.id # issued_by_id 조건을 빼면 다중 교사 동시 클릭도 소프트 차단
      )
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

      if scope.where("issued_at >= ?", now - DUP_WINDOW).exists?
        message = t("coupons.draw.duplicate")
        load_recent_issued_coupons! 
        respond_to do |f|
          f.html { redirect_to classroom_path(@classroom), alert: message,
            status: :conflict }
          f.turbo_stream do
            flash.now[:alert] = message
            render :draw_coupon, layout: "application", status: :conflict,
              locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
          end
          f.json { render json: { ok: false, error: "duplicate_request" }, status: :conflict }
        end
        return
      end

      # 첫 요청만 여기 도달 → 발급 실행
      issued = CouponDraw::Issue.call(
        classroom:     @classroom,
        basis:         basis,
        mode:          mode,
        issued_by:     current_user,
        target_user_id: params[:user_id]
      )

      winner = issued.user
      template = issued.coupon_template
      winner_coupons = policy_scope(UserCoupon)
        .where(user_id: winner.id, classroom_id: @classroom.id, status: "issued")
        .includes(:coupon_template)
        .order(created_at: :desc)
        .load
      winner_recent_issued_coupons = policy_scope(UserCoupon)
        .where(user_id: winner.id, classroom_id: @classroom.id)
        .includes(:coupon_template, :user)
        .order(issued_at: :desc)
        .limit(10)
        .load
      winner_kpi_counts = build_kpi_counts_for(user: winner, classroom: @classroom)

      notice_message = t("coupons.draw.success", name: winner.name, title: template.title)
      @play_coupon_animation = true

      if %w[daily weekly monthly].include?(basis)
        enabled_periods = @classroom.enabled_compliment_king_periods
        @selected_period = basis
        @selected_section = build_compliment_king_sections(enabled_periods: enabled_periods).fetch(@selected_period)
        @issued_winner_ids = build_issued_compliment_king_winner_ids(period: @selected_period, section: @selected_section)
      end

    end

    load_recent_issued_coupons! 
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), notice: notice_message, status: :see_other }
      f.turbo_stream do
          flash.now[:notice] = notice_message
          render :draw_coupon, layout: "application",
            locals: {
              winner: winner,
              winner_coupons: winner_coupons,
              winner_recent_issued_coupons: winner_recent_issued_coupons,
              winner_kpi_counts: winner_kpi_counts,
              issued_coupons: @issued_coupons
            }
      end
      f.json do
          render json: { coupon_id: issued.id, title: template.title, user_id: winner.id },
            status: :created
      end
    end

  rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
    # 부분 유니크 인덱스(status=0 & daily)에 걸린 경우
    message = t("coupons.draw.already_issued_today")
    load_recent_issued_coupons!
    respond_to do |f|
      f.html  { redirect_to classroom_path(@classroom), alert: message, status: :conflict }
      f.turbo_stream do
        flash.now[:alert] = message
        render :draw_coupon, layout: "application", status: :conflict,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      f.json  { render json: { ok: false, error: "already_issued_today" }, status: :conflict }
    end

  rescue ActiveRecord::RecordNotFound => e
    message = t("coupons.draw.not_found")
    load_recent_issued_coupons! 
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), alert: message, status: :not_found }
      f.turbo_stream do
        flash.now[:alert] = message
        render layout: "application", status: :not_found,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      f.json { render json: { ok: false, error: "not_found", detail: e.message }, status: :not_found }
    end

  rescue CouponDraw::Issue::Error => e
    message = t(e.i18n_key)
    load_recent_issued_coupons!
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), alert: message, status: e.http_status }

      f.turbo_stream do
        flash.now[:alert] = message
        render :draw_coupon, layout: "application", status: e.http_status,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      f.json { render json: { ok: false, error: "invalid", detail: e.i18n_key }, status: e.http_status }
    end

  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    message = t("coupons.draw.invalid", reason: e.message)
    load_recent_issued_coupons! 
    respond_to do |f|
      f.html { redirect_to classroom_path(@classroom), alert: message, status: :unprocessable_entity }
      f.turbo_stream do
        flash.now[:alert] = message
        render layout: "application", status: :unprocessable_entity,
          locals: { winner: winner, winner_coupons: winner_coupons, issued_coupons: @issued_coupons }
      end
      f.json { render json: { ok: false, error: "invalid", detail: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def classroom_destroy_error_message
    @classroom.errors.full_messages.to_sentence.presence || t("classrooms.destroy.failure")
  end

  def classroom_params
    permitted = %i[name]
    permitted.concat(operation_setting_attributes) if operation_settings_allowed?
    permitted << :grade if current_user.admin? || current_user_school_manager?
    permitted << :school_id if current_user.admin?

    params.require(:classroom).permit(*permitted.uniq)
  end

  def operation_setting_attributes
    %i[
      daily_compliment_king_enabled
      weekly_compliment_king_enabled
      monthly_compliment_king_enabled
      message_policy
    ]
  end

  def operation_settings_allowed?
    return true if current_user.admin?
    return false unless defined?(@classroom) && @classroom.present?

    policy(@classroom).manage_members?
  end

  def update_classroom_with_teacher_assignments
    return false if manager_school_change_attempt?

    selected_teacher_ids if can_assign_teachers? && teacher_assignment_params_submitted?
    return false if teacher_assignment_invalid?
    return false if teacher_school_assignment_conflict?

    Classroom.transaction do
      next false unless @classroom.update(classroom_params)

      sync_teacher_assignments if can_assign_teachers? && teacher_assignment_params_submitted?
      true
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    false
  end

  def load_teacher_assignment_form
    @assignable_teachers = assignable_teachers
    @teacher_assignment_notice_key = teacher_assignment_notice_key
    @assigned_teacher_ids = @classroom.classroom_memberships
      .teacher
      .joins(:user)
      .where(users: { role: "teacher" })
      .pluck(:user_id)
  end

  def load_school_options
    @school_options = policy_scope(School).order(:name, :id)
  end

  def load_new_classroom_teacher_assignment_form
    @assignable_teachers = assignable_teachers
    @teacher_assignment_notice_key = teacher_assignment_notice_key
    @assigned_teacher_ids = selected_teacher_ids
  end

  def create_classroom_with_teacher_assignments
    return false if unavailable_teacher_assignment_submitted?

    selected_teacher_ids if can_assign_teachers?
    return false if teacher_assignment_invalid?
    return false if teacher_school_assignment_conflict?

    Classroom.transaction do
      next false unless @classroom.save

      teacher_ids = can_assign_teachers? ? selected_teacher_ids : [current_user.id]
      teacher_ids.each do |teacher_id|
        ClassroomMembership.create!(
          classroom: @classroom,
          user_id: teacher_id,
          role: "teacher"
        )
      end
      true
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    false
  end

  def sync_teacher_assignments
    current_teacher_memberships = @classroom.classroom_memberships
      .teacher
      .joins(:user)
      .where(users: { role: "teacher" })

    current_teacher_ids = current_teacher_memberships.pluck(:user_id)
    teacher_ids_to_add = selected_teacher_ids - current_teacher_ids
    teacher_ids_to_remove = current_teacher_ids - selected_teacher_ids

    teacher_ids_to_add.each do |teacher_id|
      ClassroomMembership.find_or_create_by!(
        classroom: @classroom,
        user_id: teacher_id,
        role: "teacher"
      )
    end

    current_teacher_memberships.where(user_id: teacher_ids_to_remove).destroy_all
  end

  def teacher_school_assignment_conflict?
    return false unless can_assign_teachers?

    target_school_id = teacher_assignment_school_id
    return false unless target_school_id

    teacher_ids =
      if teacher_assignment_params_submitted? || @classroom.new_record?
        selected_teacher_ids
      else
        @classroom.classroom_memberships.teacher.joins(:user).where(users: { role: "teacher" }).pluck(:user_id)
      end

    conflict = SchoolMembership.where(user_id: teacher_ids, school_id: target_school_id).count != teacher_ids.size
    if conflict
      @classroom.errors.add(:base, t("classrooms.errors.teacher_school_required"))
    end
    conflict
  end

  def selected_teacher_ids
    return @selected_teacher_ids if defined?(@selected_teacher_ids)

    raw_ids = Array(params.dig(:classroom, :teacher_ids)).reject { |value| value == "" }
    valid_raw_ids = raw_ids.select { |value| value.to_s.match?(/\A[1-9]\d*\z/) }
    requested_ids = valid_raw_ids.map(&:to_i).uniq
    @selected_teacher_ids = assignable_teachers.where(id: requested_ids).pluck(:id)

    if valid_raw_ids.size != raw_ids.size || @selected_teacher_ids.sort != requested_ids.sort
      invalid_teacher_assignment(
        @selected_teacher_ids,
        requested_ids: requested_ids,
        malformed: valid_raw_ids.size != raw_ids.size
      )
    end
    @selected_teacher_ids
  end

  def invalid_teacher_assignment(selected_ids, requested_ids:, malformed:)
    @teacher_assignment_invalid = true
    @classroom.errors.add(:base, t(teacher_assignment_error_key(requested_ids, malformed: malformed)))
    @selected_teacher_ids = selected_ids
  end

  def teacher_assignment_error_key(requested_ids, malformed:)
    return "classrooms.errors.teacher_not_found" if malformed
    return "classrooms.errors.teacher_not_found" unless User.teacher.where(id: requested_ids).count == requested_ids.size

    "classrooms.errors.teacher_school_required"
  end

  def teacher_assignment_invalid?
    @teacher_assignment_invalid == true
  end

  def teacher_assignment_params_submitted?
    params.require(:classroom).key?(:teacher_ids)
  end

  def prepare_classroom_form
    load_school_options if current_user.admin?
    load_new_classroom_teacher_assignment_form if @classroom.new_record? && can_assign_teachers?
    load_teacher_assignment_form if @classroom.persisted? && can_assign_teachers?
  end

  def assignable_teachers
    school_id = teacher_assignment_school_id
    return User.none unless school_id

    User.teacher
      .joins(:school_membership)
      .where(school_memberships: { school_id: school_id })
      .order(:name, :id)
  end

  def can_assign_teachers?
    current_user.admin? || current_user_school_manager?
  end

  def unavailable_teacher_assignment_submitted?
    return false unless current_user.admin? && @classroom.new_record?
    return false unless teacher_assignment_params_submitted?
    return false if Array(params.dig(:classroom, :teacher_ids)).reject(&:blank?).empty?

    @teacher_assignment_invalid = true
    @classroom.errors.add(:base, t("classrooms.errors.teacher_assignment_after_create"))
    true
  end

  def teacher_assignment_school_id
    return current_user.school_membership&.school_id if current_user_school_manager?
    return nil if @classroom.new_record?

    params.dig(:classroom, :school_id).presence || @classroom.school_id
  end

  def teacher_assignment_notice_key
    return "classrooms.form.teacher_assignment_after_create" if current_user.admin? && @classroom.new_record?
    return "classrooms.form.teacher_assignment_school_required" if teacher_assignment_school_id.blank?
    return "classrooms.form.teacher_assignment_empty" if @assignable_teachers.empty?

    nil
  end

  def current_user_school_manager?
    current_user&.teacher? && current_user.school_membership&.manager?
  end

  def prepare_school_filter
    @filter_schools = policy_scope(School).order(:name, :id).load
    @selected_school = @filter_schools.detect { |school| school.id == school_filter_id }
  end

  def school_filter_id
    value = params[:school_id].to_s
    return nil unless value.match?(/\A[1-9]\d*\z/)

    value.to_i
  end

  def assign_manager_school
    return unless current_user_school_manager?

    @classroom.school = current_user.school_membership.school
  end

  def manager_school_change_attempt?
    return false unless current_user_school_manager?
    return false unless params.require(:classroom).key?(:school_id)
    return false if params.dig(:classroom, :school_id).to_s == @classroom.school_id.to_s

    @classroom.errors.add(:base, t("classrooms.errors.manager_school_change"))
    true
  end

  def redirect_students_to_mypage!
    return unless current_user&.student?

    redirect_to user_path(current_user)
  end

  def classroom_membership_previews(classroom_ids, role:, limit_per_classroom:, user_role: nil)
    return {} if classroom_ids.empty?

    membership_scope = ClassroomMembership.where(classroom_id: classroom_ids, role: role)
    membership_scope = membership_scope.joins(:user).where(users: { role: user_role }) if user_role

    ranked_membership_ids = ClassroomMembership
      .from(
        membership_scope
          .select(
            "classroom_memberships.id, classroom_memberships.classroom_id, " \
            "ROW_NUMBER() OVER (PARTITION BY classroom_memberships.classroom_id " \
            "ORDER BY classroom_memberships.created_at ASC, classroom_memberships.id ASC) AS preview_position"
          ),
        :classroom_memberships
      )
      .where("preview_position <= ?", limit_per_classroom)
      .pluck(:id)

    ClassroomMembership
      .where(id: ranked_membership_ids)
      .includes(user: { avatar_attachment: :blob })
      .order(:classroom_id, :created_at, :id)
      .group_by(&:classroom_id)
      .transform_values { |memberships| memberships.map(&:user) }
  end

  def classrooms_index_title_key
    return "classrooms.index.admin_title" if current_user.admin?
    return "classrooms.index.manager_title" if current_user_school_manager?

    "classrooms.index.teacher_title"
  end

  def load_recent_issued_coupons!
    @issued_coupons = policy_scope(UserCoupon).where(classroom_id: @classroom.id)
      .includes(:user, :coupon_template)
      .order(created_at: :desc)
      .limit(5)
      .load
  end

  def student_ids_with_pending_coupon_use_requests
    return Set.new unless @can_manage_classroom

    Set.new(CouponUseRequest
      .pending
      .where(classroom_id: @classroom.id, student_id: @students.select(:id))
      .distinct
      .pluck(:student_id))
  end

  def student_ids_with_unread_student_messages
    return Set.new unless @can_manage_classroom
    return Set.new unless @classroom.student_messages_enabled?

    Set.new(UserMessage
      .unread_student_messages
      .where(classroom_id: @classroom.id, sender_id: @students.select(:id))
      .distinct
      .pluck(:sender_id))
  end

  def qr_png_data_url(text)
    "data:image/png;base64,#{Base64.strict_encode64(qr_png_binary(text))}"
  end

  def qr_png_binary(text)
    RQRCode::QRCode.new(text).as_png(size: 320).to_s
  end

  def build_compliment_king_sections(enabled_periods:)
    Classroom::COMPLIMENT_KING_PERIODS.filter_map do |period|
      next unless enabled_periods.include?(period)

      [period, ComplimentKings::Pick.call(classroom: @classroom, period: period)]
    end.to_h
  end

  def build_compliment_king_period_cards(enabled_periods:)
    enabled_periods.map do |period|
      {
        period: period,
        frame_id: view_context.dom_id(@classroom, :"compliment_king_#{period}")
      }
    end
  end

  def refreshable_compliment_king_periods(enabled_periods)
    enabled_periods.select do |period|
      @classroom.compliment_king_refresh_available_for?(period)
    end
  end

  def build_issued_compliment_king_winner_ids(period:, section:)
    return [] unless section.present? && section.winners.present?

    UserCoupon.where(
      user_id: section.winners.map(&:id),
      classroom_id: @classroom.id,
      issuance_basis: period,
      basis_tag: "#{period}_top",
      period_start_on: UserCoupon.period_start_for(period)
    ).pluck(:user_id)
  end

  def normalized_basis_and_mode(basis_param, mode_param)
    basis = case basis_param
            when "manual" then "manual"
            when "weekly" then "weekly"
            when "monthly" then "monthly"
            else "daily"
            end
    mode = if mode_param.present?
            mode_param.to_s
          else
            basis == "manual" ? "default" : "#{basis}_top"
          end

    [basis, mode]
  end

  def build_kpi_counts_for(user:, classroom:)
    compliments_scope = policy_scope(Compliment).where(receiver_id: user.id, classroom_id: classroom.id)
    coupons_scope = policy_scope(UserCoupon).where(user_id: user.id, classroom_id: classroom.id)

    {
      points: user.points,
      today_compliments: compliments_scope.where(given_at: Time.zone.today.all_day).count,
      issued_count: coupons_scope.where(status: "issued").count,
      today_issued_coupons: coupons_scope.where(issued_at: Time.zone.today.all_day).count,
      used_coupons: coupons_scope.where(status: "used").count
    }
  end

end
