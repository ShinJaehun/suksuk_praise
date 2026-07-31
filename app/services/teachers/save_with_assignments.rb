module Teachers
  class SaveWithAssignments
    Result = Data.define(:teacher, :error_messages) do
      def success?
        error_messages.empty?
      end
    end

    def self.call(teacher:, attributes:, school:, classroom_ids:, assignment_scope: :all)
      new(
        teacher: teacher,
        attributes: attributes,
        school: school,
        classroom_ids: classroom_ids,
        assignment_scope: assignment_scope
      ).call
    end

    def initialize(teacher:, attributes:, school:, classroom_ids:, assignment_scope:)
      @teacher = teacher
      @attributes = attributes
      @school = school
      @raw_classroom_ids = Array(classroom_ids)
      @assignment_scope = assignment_scope
    end

    def call
      teacher.assign_attributes(attributes)
      validate_inputs
      return result if teacher.errors.any?

      User.transaction do
        teacher.save! if teacher.new_record?
        remove_teacher_assignments!
        sync_school_membership!
        add_teacher_assignments!
        teacher.save! if teacher.persisted? && teacher.changed?
      end

      result
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotDestroyed => error
      copy_persistence_errors(error)
      result
    end

    private

    attr_reader :teacher, :attributes, :school, :raw_classroom_ids, :assignment_scope

    def validate_inputs
      validate_teacher
      normalize_classroom_ids
      validate_school
      validate_classrooms
      validate_inactive_school
    end

    def validate_teacher
      return if teacher&.teacher?

      add_error(:teacher_required)
    end

    def normalize_classroom_ids
      values = raw_classroom_ids.reject(&:blank?)
      valid_values = values.select { |value| value.to_s.match?(/\A[1-9]\d*\z/) }
      @classroom_ids = valid_values.map(&:to_i).uniq
      add_error(:classroom_not_found) if valid_values.size != values.size
    end

    def validate_school
      return if school.nil? || school.is_a?(School)

      add_error(:school_not_found)
    end

    def validate_classrooms
      return if teacher.errors.any?

      @classrooms_by_id = Classroom.where(id: classroom_ids).index_by(&:id)
      if classrooms_by_id.size != classroom_ids.size
        add_error(:classroom_not_found)
      elsif school.nil? && classroom_ids.any?
        add_error(:school_required_for_classrooms)
      elsif school && classrooms_by_id.values.any? { |classroom| classroom.school_id != school.id }
        add_error(:classroom_school_mismatch)
      end
    end

    def validate_inactive_school
      return unless school&.inactive?

      current_membership = teacher.school_membership
      if current_membership&.school_id != school.id
        add_inactive_school_error
        return
      end

      add_inactive_school_error if (classroom_ids - managed_assignment_ids).any?
    end

    def remove_teacher_assignments!
      memberships = managed_assignments
      ids_to_remove =
        if school_changed?
          memberships.pluck(:classroom_id)
        else
          memberships.pluck(:classroom_id) - classroom_ids
        end

      memberships.where(classroom_id: ids_to_remove).find_each(&:destroy!)
    end

    def sync_school_membership!
      membership = teacher.school_membership

      if school.nil?
        membership&.destroy!
      elsif membership
        changes = { school: school }
        changes[:role] = :member if membership.school_id != school.id
        membership.update!(changes)
      else
        teacher.create_school_membership!(school: school)
      end
    end

    def add_teacher_assignments!
      current_ids = managed_assignments.pluck(:classroom_id)
      (classroom_ids - current_ids).each do |classroom_id|
        ClassroomMembership.create!(
          user: teacher,
          classroom_id: classroom_id,
          role: :teacher,
          status: :active
        )
      end
    end

    def managed_assignments
      scope = teacher.classroom_memberships.teacher
      return scope unless assignment_scope == :school

      scope.joins(:classroom).where(classrooms: { school_id: school.id })
    end

    def managed_assignment_ids
      return [] unless teacher.persisted?

      managed_assignments.pluck(:classroom_id)
    end

    def school_changed?
      current_school_id = teacher.school_membership&.school_id
      current_school_id.present? && current_school_id != school&.id
    end

    def classroom_ids
      @classroom_ids ||= []
    end

    def classrooms_by_id
      @classrooms_by_id ||= {}
    end

    def add_error(key)
      teacher.errors.add(:base, I18n.t("admin.teachers.errors.#{key}"))
    end

    def add_inactive_school_error
      teacher.errors.add(:base, I18n.t("school_status.inactive_school"))
    end

    def copy_persistence_errors(error)
      record = error.respond_to?(:record) ? error.record : nil
      if record.equal?(teacher)
        return
      elsif record&.errors&.any?
        record.errors.full_messages.each { |message| teacher.errors.add(:base, message) }
      else
        add_error(:assignment_save_failed)
      end
    end

    def result
      Result.new(teacher: teacher, error_messages: teacher.errors.full_messages)
    end
  end
end
