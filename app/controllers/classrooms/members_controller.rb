class Classrooms::MembersController < ApplicationController
  MEMBER_STATUS_FILTERS = %w[active inactive all].freeze

  before_action :authenticate_user!
  before_action :set_classroom

  def show
    authorize @classroom, :manage_members?
    load_members_page!
  end

  def edit_student_names
    authorize @classroom, :manage_members?
    @member_status = member_status_filter
    load_student_name_memberships

    render :edit_student_names, layout: false
  end

  def update_student_names
    authorize @classroom, :manage_members?

    @member_status = member_status_filter
    @submitted_student_roster = student_roster_params
    saved = false

    @classroom.with_lock do
      load_student_name_memberships
      editable_memberships_by_id = @student_name_memberships.index_by { |membership| membership.id.to_s }

      unless (@submitted_student_roster.keys - editable_memberships_by_id.keys).empty?
        @student_roster_errors_by_membership_id = {}
        @student_roster_error_key = :invalid_membership
        next
      end
      memberships_by_id = editable_memberships_by_id.slice(*@submitted_student_roster.keys)

      assign_and_validate_student_roster(memberships_by_id)
      next if @student_roster_errors_by_membership_id.any?

      changed_active_memberships = memberships_by_id.values.select do |membership|
        membership.active? && membership.will_save_change_to_student_number?
      end
      ClassroomMembership.where(id: changed_active_memberships.map(&:id))
        .update_all(student_number: nil) if changed_active_memberships.any?

      memberships_by_id.each_value do |membership|
        membership.user.save! if membership.user.has_changes_to_save?
      end
      memberships_by_id.each_value do |membership|
        membership.save! if membership.has_changes_to_save?
      end
      saved = true
    end

    return render_student_roster_errors(@student_roster_error_key || :failure) unless saved

    respond_to do |format|
      format.html do
        redirect_to members_redirect_path,
          notice: t("students.members.update_names.success"),
          status: :see_other
      end
      format.turbo_stream do
        load_members_page!
        flash.now[:notice] = t("students.members.update_names.success")
        render :update_student_names, layout: false
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    attach_record_error(e.record)
    load_student_name_memberships
    render_student_roster_errors(:failure)
  rescue ActiveRecord::RecordNotUnique
    attach_record_not_unique_errors
    load_student_name_memberships
    render_student_roster_errors(:failure)
  end

  def edit_student_pin
    authorize @classroom, :manage_members?
    @student_pin = ""

    render :edit_student_pin, layout: false
  end

  def update_student_pin
    authorize @classroom, :manage_members?

    @student_pin = params[:student_pin].to_s
    @student_pin_error = student_pin_error_message(@student_pin)
    return render_student_pin_error if @student_pin_error.present?

    memberships = active_student_memberships.to_a
    if memberships.empty?
      @student_pin_error = t("students.members.pin_reset.no_active_students")
      return render_student_pin_error
    end

    ApplicationRecord.transaction do
      memberships.each { |membership| membership.user.update!(student_pin: @student_pin) }
    end

    respond_to do |format|
      format.html do
        redirect_to classroom_members_path(@classroom),
          notice: t("students.members.pin_reset.success", count: memberships.size),
          status: :see_other
      end
      format.turbo_stream do
        flash.now[:notice] = t("students.members.pin_reset.success", count: memberships.size)
        render :update_student_pin, layout: false
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @student_pin_error = t(
      "students.members.pin_reset.failure",
      detail: e.record.errors.full_messages.to_sentence
    )
    render_student_pin_error
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def load_student_memberships
    @member_status = member_status_filter
    base_scope = @classroom.classroom_memberships.student
    status_counts = base_scope.group(:status).count
    @student_member_counts = {
      "active" => status_counts.fetch("active", 0),
      "inactive" => status_counts.fetch("inactive", 0)
    }
    @student_member_counts["all"] = @student_member_counts.values.sum

    @student_memberships =
      if @member_status == "all"
        base_scope
          .order(Arel.sql("CASE classroom_memberships.status WHEN 'active' THEN 0 ELSE 1 END"))
          .in_roster_order
          .preload(:user)
      else
        base_scope
          .where(status: @member_status)
          .in_roster_order
          .preload(:user)
      end
  end

  def load_members_page!
    load_student_memberships
  end

  def member_status_filter
    params[:status].to_s.presence_in(MEMBER_STATUS_FILTERS) || "active"
  end

  def active_student_memberships
    @classroom.classroom_memberships
      .student
      .active
      .includes(:user)
      .order(:created_at, :id)
  end

  def load_student_name_memberships
    @member_status ||= member_status_filter
    base_scope = @classroom.classroom_memberships.student
    @student_name_memberships =
      if @member_status == "all"
        base_scope
          .order(Arel.sql("CASE classroom_memberships.status WHEN 'active' THEN 0 ELSE 1 END"))
          .in_roster_order
          .preload(user: { avatar_attachment: :blob })
      else
        base_scope
          .where(status: @member_status)
          .in_roster_order
          .preload(user: { avatar_attachment: :blob })
      end
  end

  def student_pin_error_message(pin)
    return t("students.members.pin_reset.blank") if pin.blank?
    return t("students.members.pin_reset.invalid") unless pin.match?(/\A\d{4}\z/)

    nil
  end

  def render_student_pin_error
    respond_to do |format|
      format.html do
        flash.now[:alert] = @student_pin_error
        render :edit_student_pin, status: :unprocessable_entity
      end
      format.turbo_stream do
        flash.now[:alert] = @student_pin_error
        render :edit_student_pin, formats: :html, layout: false, status: :unprocessable_entity
      end
    end
  end

  def render_student_roster_errors(error_key)
    respond_to do |format|
      format.html do
        flash.now[:alert] = t("students.members.update_names.#{error_key}")
        render :edit_student_names, status: :unprocessable_entity, layout: false
      end
      format.turbo_stream do
        flash.now[:alert] = t("students.members.update_names.#{error_key}")
        render :edit_student_names, formats: :html, status: :unprocessable_entity, layout: false
      end
    end
  end

  def members_redirect_path
    return classroom_members_path(@classroom, status: member_status_filter) if params.key?(:status)

    classroom_members_path(@classroom)
  end

  def student_roster_params
    raw_students = params.fetch(:students, {})
    raw_students = raw_students.to_unsafe_h if raw_students.respond_to?(:to_unsafe_h)

    raw_students.each_with_object({}) do |(membership_id, attrs), result|
      attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
      attrs = attrs.to_h if attrs.respond_to?(:to_h)
      attrs = {} unless attrs.respond_to?(:key?)
      result[membership_id.to_s] = %w[student_number name gender avatar_key].each_with_object({}) do |key, permitted|
        permitted[key] = attrs[key].to_s if attrs.key?(key)
      end
    end
  end

  def assign_and_validate_student_roster(memberships_by_id)
    @student_roster_errors_by_membership_id = Hash.new { |hash, key| hash[key] = [] }

    memberships_by_id.each do |membership_id, membership|
      attrs = @submitted_student_roster.fetch(membership_id)
      assign_student_number(membership_id, membership, attrs)
      assign_student_profile(membership_id, membership, attrs)
    end

    validate_final_active_student_numbers(memberships_by_id)

    memberships_by_id.each do |membership_id, membership|
      next if membership.user.valid?

      @student_roster_errors_by_membership_id[membership_id].concat(
        membership.user.errors.full_messages
      )
    end
    @student_roster_errors_by_membership_id.delete_if { |_id, errors| errors.empty? }
  end

  def assign_student_number(membership_id, membership, attrs)
    raw_number = attrs.fetch("student_number", membership.student_number_before_type_cast.to_s)
    attrs["student_number"] = raw_number
    if raw_number.present? && !raw_number.match?(/\A[1-9]\d*\z/)
      @student_roster_errors_by_membership_id[membership_id] <<
        t("students.members.update_names.invalid_student_number")
      return
    end

    membership.student_number = raw_number.presence
  end

  def assign_student_profile(membership_id, membership, attrs)
    user = membership.user
    original_gender = user.gender
    original_avatar_key = user.avatar_key
    user.name = attrs.fetch("name", user.name)

    if attrs.key?("gender")
      gender = attrs["gender"]
      unless %w[boy girl].include?(gender)
        @student_roster_errors_by_membership_id[membership_id] <<
          t("students.members.update_names.invalid_gender")
        return
      end
      user.gender = gender
    end

    submitted_avatar_key = attrs.fetch("avatar_key", user.avatar_key.to_s)
    attrs["avatar_key"] = normalized_roster_avatar_key(
      membership,
      submitted_avatar_key,
      original_gender: original_gender,
      original_avatar_key: original_avatar_key
    )
    if attrs["avatar_key"].present? &&
        !User.avatar_keys_for(user.gender).include?(attrs["avatar_key"]) &&
        attrs["avatar_key"] != user.avatar_key
      @student_roster_errors_by_membership_id[membership_id] <<
        t("students.members.update_names.invalid_avatar")
      return
    end
    user.avatar_key = attrs["avatar_key"].presence
  end

  def normalized_roster_avatar_key(
    membership,
    submitted_avatar_key,
    original_gender:,
    original_avatar_key:
  )
    user = membership.user
    pool = User.avatar_keys_for(user.gender)
    gender_changed = user.gender != original_gender
    return submitted_avatar_key if !gender_changed && submitted_avatar_key == original_avatar_key
    return submitted_avatar_key if pool.include?(submitted_avatar_key)
    return submitted_avatar_key if user.gender.blank?
    return submitted_avatar_key unless submitted_avatar_key.blank? || submitted_avatar_key == original_avatar_key

    row_index = @student_name_memberships.index(membership) || 0
    pool[row_index % pool.length]
  end

  def validate_final_active_student_numbers(memberships_by_id)
    submitted_numbers = memberships_by_id.transform_values(&:student_number)
    final_numbers = @classroom.classroom_memberships.student.active.map do |membership|
      [membership, submitted_numbers.fetch(membership.id.to_s, membership.student_number)]
    end

    final_numbers
      .reject { |_membership, number| number.nil? }
      .group_by { |_membership, number| number }
      .each_value do |rows|
        next unless rows.many?

        rows.each do |membership, number|
          membership_id = membership.id.to_s
          next unless memberships_by_id.key?(membership_id)

          @student_roster_errors_by_membership_id[membership_id] <<
            t("students.members.update_names.duplicate_student_number", number: number)
        end
      end
  end

  def attach_record_error(record)
    @student_roster_errors_by_membership_id ||= Hash.new { |hash, key| hash[key] = [] }
    membership =
      if record.is_a?(ClassroomMembership)
        record
      else
        @student_name_memberships&.find { |candidate| candidate.user == record }
      end
    return unless membership

    @student_roster_errors_by_membership_id[membership.id.to_s].concat(
      record.errors.full_messages
    )
  end

  def attach_record_not_unique_errors
    @student_roster_errors_by_membership_id ||= Hash.new { |hash, key| hash[key] = [] }
    @submitted_student_roster.each do |membership_id, attrs|
      next if attrs["student_number"].blank?
      membership = @student_name_memberships&.find { |candidate| candidate.id.to_s == membership_id }
      next unless membership&.active?

      @student_roster_errors_by_membership_id[membership_id] <<
        t("students.members.update_names.duplicate_student_number",
          number: attrs["student_number"])
    end
  end

end
