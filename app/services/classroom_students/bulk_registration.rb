module ClassroomStudents
  class BulkRegistration
    Result = Struct.new(:students, :rows, :error, :row_errors, keyword_init: true) do
      def success?
        error.blank?
      end
    end

    def self.preview(classroom:, student_pin:, student_count:)
      new(
        classroom: classroom,
        student_pin: student_pin,
        rows: {}
      ).validate_setup(student_count)
    end

    def self.call(classroom:, student_pin:, rows:)
      new(classroom: classroom, student_pin: student_pin, rows: rows).call
    end

    def initialize(classroom:, student_pin:, rows:)
      @classroom = classroom
      @student_pin = student_pin.to_s.strip
      @rows = normalize_rows(rows)
    end

    def validate_setup(student_count)
      error =
        if !student_count.to_s.match?(/\A[1-9]\d*\z/)
          translate("students.bulk_create.errors.invalid_count")
        elsif active_student_limit_exceeded?(student_count.to_i)
          active_student_limit_error
        elsif !valid_pin?
          translate("students.bulk_create.errors.invalid_pin")
        end

      @rows = build_rows(student_count.to_i) if error.blank?
      Result.new(students: [], rows: @rows, error: error, row_errors: {})
    end

    def call
      error, row_errors = validate_rows
      return failure(error, row_errors) if error.present?

      created = []
      current_row = nil
      limit_error = nil

      @classroom.with_lock do
        if active_student_limit_exceeded?(@rows.size)
          limit_error = active_student_limit_error
          next
        end

        @rows.each do |row|
          current_row = row
          user = User.create!(
            name: row[:name],
            role: "student",
            points: 0,
            gender: row[:gender],
            avatar_key: row[:avatar_key],
            student_pin: @student_pin
          )
          @classroom.classroom_memberships.create!(
            user: user,
            role: "student",
            status: "active",
            student_number: row[:student_number]
          )
          created << user
        end
      end

      return failure(limit_error, {}) if limit_error.present?

      Result.new(students: created, rows: @rows, error: nil, row_errors: {})
    rescue ActiveRecord::RecordInvalid => e
      message =
        if e.record.is_a?(ClassroomMembership) && e.record.errors[:student_number].any?
          student_number_taken_error(current_row)
        else
          translate(
            "students.bulk_create.failure",
            detail: e.record.errors.full_messages.to_sentence
          )
        end
      failure(message, error_for(current_row, message))
    rescue ActiveRecord::RecordNotUnique
      message = student_number_taken_error(current_row)
      failure(message, error_for(current_row, message))
    end

    private

    def normalize_rows(rows)
      raw_rows = rows.respond_to?(:to_unsafe_h) ? rows.to_unsafe_h : rows
      raw_rows = raw_rows.to_h if raw_rows.respond_to?(:to_h)
      raw_rows = {} unless raw_rows.respond_to?(:each_with_index)

      raw_rows.each_with_index.map do |(index, attributes), fallback_index|
        attributes = attributes.to_unsafe_h if attributes.respond_to?(:to_unsafe_h)
        attributes = attributes.to_h if attributes.respond_to?(:to_h)
        attributes = {} unless attributes.respond_to?(:fetch)

        {
          index: index.presence || fallback_index.to_s,
          student_number: fetch_attribute(attributes, :student_number).to_s,
          name: fetch_attribute(attributes, :name).to_s,
          gender: fetch_attribute(attributes, :gender).to_s,
          avatar_key: fetch_attribute(attributes, :avatar_key).to_s
        }
      end
    end

    def build_rows(student_count)
      Array.new(student_count) do |index|
        {
          index: index.to_s,
          student_number: (index + 1).to_s,
          name: "",
          gender: "",
          avatar_key: ""
        }
      end
    end

    def fetch_attribute(attributes, key)
      attributes.fetch(key.to_s) { attributes.fetch(key, "") }
    end

    def validate_rows
      errors = {}
      errors[:base] = translate("students.bulk_create.errors.empty") if @rows.empty?
      errors[:base] = active_student_limit_error if active_student_limit_exceeded?(@rows.size)
      errors[:base] = translate("students.bulk_create.errors.invalid_pin") unless valid_pin?

      numbered_rows = @rows.select { |row| valid_student_number?(row[:student_number]) }
      duplicate_numbers = numbered_rows
        .group_by { |row| row[:student_number].to_i }
        .select { |_number, matching_rows| matching_rows.many? }
        .keys
      existing_numbers = @classroom.classroom_memberships.student.active
        .where(student_number: numbered_rows.map { |row| row[:student_number].to_i })
        .pluck(:student_number)

      @rows.each do |row|
        row_errors = validate_row(row, duplicate_numbers, existing_numbers)
        errors[row[:index]] = row_errors if row_errors.any?
      end

      [errors[:base] || errors.values.flatten.first, errors.except(:base)]
    end

    def validate_row(row, duplicate_numbers, existing_numbers)
      errors = []
      number = row[:student_number]

      if number.blank?
        errors << translate("students.create.errors.student_number_required")
      elsif !valid_student_number?(number)
        errors << translate("students.create.errors.student_number_invalid")
      elsif duplicate_numbers.include?(number.to_i)
        errors << translate(
          "students.bulk_create.errors.student_number_duplicate_in_draft",
          number: number
        )
      elsif existing_numbers.include?(number.to_i)
        errors << translate("students.bulk_create.errors.student_number_taken", number: number)
      end

      errors << translate("students.bulk_create.errors.name_required") if row[:name].blank?
      unless %w[boy girl].include?(row[:gender])
        errors << translate("students.bulk_create.errors.gender_required")
      end
      if row[:avatar_key].blank?
        errors << translate("students.bulk_create.errors.avatar_required")
      elsif !student_avatar_matches_gender?(row[:gender], row[:avatar_key])
        errors << translate("students.bulk_create.errors.invalid_avatar")
      end

      errors
    end

    def valid_student_number?(number)
      number.match?(/\A[1-9]\d*\z/)
    end

    def valid_pin?
      @student_pin.match?(/\A\d{4}\z/)
    end

    def student_avatar_matches_gender?(gender, avatar_key)
      User.avatar_keys_for_role("student").include?(avatar_key) &&
        User.avatar_keys_for(gender).include?(avatar_key)
    end

    def active_student_limit_exceeded?(new_count)
      @classroom.active_student_memberships_count + new_count > Classroom::MAX_ACTIVE_STUDENTS
    end

    def active_student_limit_error
      translate("students.bulk_create.errors.too_many", count: Classroom::MAX_ACTIVE_STUDENTS)
    end

    def student_number_taken_error(row)
      translate(
        "students.bulk_create.errors.student_number_taken",
        number: row&.dig(:student_number)
      )
    end

    def error_for(row, message)
      row ? { row[:index] => [message] } : {}
    end

    def failure(error, row_errors)
      Result.new(students: [], rows: @rows, error: error, row_errors: row_errors)
    end

    def translate(key, **options)
      I18n.t(key, **options)
    end
  end
end
