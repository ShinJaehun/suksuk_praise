module ClassroomStudents
  class RosterUpdate
    Result = Struct.new(
      :memberships,
      :rows,
      :row_errors,
      :error_key,
      keyword_init: true
    ) do
      def success?
        error_key.nil?
      end
    end

    def self.call(classroom:, memberships:, rows:)
      new(classroom: classroom, memberships: memberships, rows: rows).call
    end

    def initialize(classroom:, memberships:, rows:)
      @classroom = classroom
      @editable_memberships = memberships
      @rows = normalize_rows(rows)
      @row_errors = Hash.new { |hash, key| hash[key] = [] }
    end

    def call
      saved = false

      @classroom.with_lock do
        @memberships = @editable_memberships.to_a
        editable_by_id = @memberships.index_by { |membership| membership.id.to_s }

        unless (@rows.keys - editable_by_id.keys).empty?
          return failure(:invalid_membership)
        end

        memberships_by_id = editable_by_id.slice(*@rows.keys)
        assign_and_validate(memberships_by_id)
        next if @row_errors.any?

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

      saved ? success : failure(:failure)
    rescue ActiveRecord::RecordInvalid => e
      attach_record_error(e.record)
      failure(:failure)
    rescue ActiveRecord::RecordNotUnique
      attach_record_not_unique_errors
      failure(:failure)
    end

    private

    def normalize_rows(rows)
      raw_rows = rows.respond_to?(:to_unsafe_h) ? rows.to_unsafe_h : rows
      raw_rows = raw_rows.to_h if raw_rows.respond_to?(:to_h)
      raw_rows = {} unless raw_rows.respond_to?(:each_with_object)

      raw_rows.each_with_object({}) do |(membership_id, attributes), result|
        attributes = attributes.to_unsafe_h if attributes.respond_to?(:to_unsafe_h)
        attributes = attributes.to_h if attributes.respond_to?(:to_h)
        attributes = {} unless attributes.respond_to?(:key?)

        result[membership_id.to_s] =
          %w[student_number name gender avatar_key].each_with_object({}) do |key, permitted|
            if attributes.key?(key)
              permitted[key] = attributes[key].to_s
            elsif attributes.key?(key.to_sym)
              permitted[key] = attributes[key.to_sym].to_s
            end
          end
      end
    end

    def assign_and_validate(memberships_by_id)
      memberships_by_id.each do |membership_id, membership|
        attributes = @rows.fetch(membership_id)
        assign_student_number(membership_id, membership, attributes)
        assign_student_profile(membership_id, membership, attributes)
      end

      validate_final_active_student_numbers(memberships_by_id)

      memberships_by_id.each do |membership_id, membership|
        next if membership.user.valid?

        @row_errors[membership_id].concat(membership.user.errors.full_messages)
      end
      @row_errors.delete_if { |_membership_id, errors| errors.empty? }
    end

    def assign_student_number(membership_id, membership, attributes)
      raw_number = attributes.fetch(
        "student_number",
        membership.student_number_before_type_cast.to_s
      )
      attributes["student_number"] = raw_number
      if raw_number.present? && !raw_number.match?(/\A[1-9]\d*\z/)
        @row_errors[membership_id] <<
          translate("students.members.update_names.invalid_student_number")
        return
      end

      membership.student_number = raw_number.presence
    end

    def assign_student_profile(membership_id, membership, attributes)
      user = membership.user
      original_gender = user.gender
      original_avatar_key = user.avatar_key
      user.name = attributes.fetch("name", user.name)

      if attributes.key?("gender")
        gender = attributes["gender"]
        unless %w[boy girl].include?(gender)
          @row_errors[membership_id] <<
            translate("students.members.update_names.invalid_gender")
          return
        end
        user.gender = gender
      end

      submitted_avatar_key = attributes.fetch("avatar_key", user.avatar_key.to_s)
      attributes["avatar_key"] = normalized_avatar_key(
        membership,
        submitted_avatar_key,
        original_gender: original_gender,
        original_avatar_key: original_avatar_key
      )
      if attributes["avatar_key"].present? &&
          !User.avatar_keys_for(user.gender).include?(attributes["avatar_key"]) &&
          attributes["avatar_key"] != user.avatar_key
        @row_errors[membership_id] <<
          translate("students.members.update_names.invalid_avatar")
        return
      end
      user.avatar_key = attributes["avatar_key"].presence
    end

    def normalized_avatar_key(
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
      return submitted_avatar_key unless submitted_avatar_key.blank? ||
        submitted_avatar_key == original_avatar_key

      row_index = @memberships.index(membership) || 0
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
        .each_value do |matching_rows|
          next unless matching_rows.many?

          matching_rows.each do |membership, number|
            membership_id = membership.id.to_s
            next unless memberships_by_id.key?(membership_id)

            @row_errors[membership_id] <<
              translate(
                "students.members.update_names.duplicate_student_number",
                number: number
              )
          end
        end
    end

    def attach_record_error(record)
      membership =
        if record.is_a?(ClassroomMembership)
          record
        else
          @memberships&.find { |candidate| candidate.user == record }
        end
      return unless membership

      @row_errors[membership.id.to_s].concat(record.errors.full_messages)
    end

    def attach_record_not_unique_errors
      @rows.each do |membership_id, attributes|
        next if attributes["student_number"].blank?

        membership = @memberships&.find { |candidate| candidate.id.to_s == membership_id }
        next unless membership&.active?

        @row_errors[membership_id] <<
          translate(
            "students.members.update_names.duplicate_student_number",
            number: attributes["student_number"]
          )
      end
    end

    def success
      Result.new(
        memberships: @memberships,
        rows: @rows,
        row_errors: @row_errors,
        error_key: nil
      )
    end

    def failure(error_key)
      Result.new(
        memberships: @memberships || Array(@editable_memberships),
        rows: @rows,
        row_errors: @row_errors,
        error_key: error_key
      )
    end

    def translate(key, **options)
      I18n.t(key, **options)
    end
  end
end
