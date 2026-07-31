module SchoolStructure
  class IntegrityAudit
    DEFAULT_SAMPLE_LIMIT = 20
    MAX_SAMPLE_LIMIT = 1_000

    ISSUE_LABELS = {
      role_mismatch: 'role mismatch',
      teacher_without_school: 'teacher without school',
      teacher_classroom_school_mismatch: 'teacher/classroom school mismatch',
      teacher_membership_with_student_number: 'teacher membership with student number',
      invalid_school_membership_user_role: 'invalid school membership user role',
      teacher_assigned_across_multiple_schools: 'teacher assigned across multiple schools'
    }.freeze

    Issue = Data.define(:count, :samples)
    Result = Data.define(:issues) do
      def clean?
        issue_count.zero?
      end

      alias_method :success?, :clean?

      def issue_count
        issues.values.sum(&:count)
      end

      def count_for(type)
        issues.fetch(type).count
      end

      def samples_for(type)
        issues.fetch(type).samples
      end
    end

    def self.call(sample_limit: DEFAULT_SAMPLE_LIMIT)
      new(sample_limit: sample_limit).call
    end

    def initialize(sample_limit:)
      @sample_limit = sample_limit.to_i.clamp(0, MAX_SAMPLE_LIMIT)
    end

    def call
      Result.new(
        issues: {
          role_mismatch: issue(role_mismatch_scope),
          teacher_without_school: issue(teacher_without_school_scope),
          teacher_classroom_school_mismatch: issue(teacher_school_mismatch_scope),
          teacher_membership_with_student_number: issue(teacher_with_student_number_scope),
          invalid_school_membership_user_role: issue(
            invalid_school_membership_scope,
            sample_scope: invalid_school_membership_sample_scope
          ),
          teacher_assigned_across_multiple_schools: cross_school_assignment_issue
        }
      )
    end

    private

    attr_reader :sample_limit

    def classroom_membership_scope
      ClassroomMembership
        .joins(:user, :classroom)
        .joins('LEFT JOIN school_memberships ON school_memberships.user_id = classroom_memberships.user_id')
    end

    def classroom_sample_scope(scope)
      scope.select(
        'classroom_memberships.id AS classroom_membership_id',
        'classroom_memberships.user_id AS user_id',
        'classroom_memberships.classroom_id AS classroom_id',
        'classrooms.school_id AS classroom_school_id',
        'school_memberships.school_id AS teacher_school_id',
        'school_memberships.id AS school_membership_id',
        'classroom_memberships.role AS role',
        'classroom_memberships.student_number AS student_number'
      )
    end

    def role_mismatch_scope
      classroom_membership_scope.where(
        '(classroom_memberships.role = :teacher AND users.role <> :teacher) OR ' \
          '(classroom_memberships.role = :student AND users.role <> :student)',
        teacher: 'teacher',
        student: 'student'
      )
    end

    def teacher_without_school_scope
      classroom_membership_scope
        .where(classroom_memberships: { role: 'teacher' })
        .where(school_memberships: { id: nil })
    end

    def teacher_school_mismatch_scope
      classroom_membership_scope
        .where(classroom_memberships: { role: 'teacher' })
        .where.not(school_memberships: { id: nil })
        .where('school_memberships.school_id <> classrooms.school_id')
    end

    def teacher_with_student_number_scope
      classroom_membership_scope
        .where(classroom_memberships: { role: 'teacher' })
        .where.not(classroom_memberships: { student_number: nil })
    end

    def invalid_school_membership_scope
      SchoolMembership
        .joins(:user)
        .where.not(users: { role: 'teacher' })
    end

    def invalid_school_membership_sample_scope
      invalid_school_membership_scope.select(
        'school_memberships.id AS school_membership_id',
        'school_memberships.user_id AS user_id',
        'school_memberships.school_id AS teacher_school_id',
        'users.role AS user_role'
      )
    end

    def cross_school_assignment_scope
      ClassroomMembership
        .teacher
        .joins(:classroom)
        .group(:user_id)
        .having('COUNT(DISTINCT classrooms.school_id) > 1')
    end

    def issue(scope, sample_scope: classroom_sample_scope(scope))
      Issue.new(
        count: scope.except(:select, :order).count,
        samples: sample_attributes(sample_scope)
      )
    end

    def cross_school_assignment_issue
      scope = cross_school_assignment_scope
      samples = scope
                .order(:user_id)
                .limit(sample_limit)
                .pluck(
                  :user_id,
                  Arel.sql('ARRAY_AGG(DISTINCT classrooms.school_id ORDER BY classrooms.school_id)')
                )
                .map { |user_id, school_ids| { 'user_id' => user_id, 'classroom_school_ids' => school_ids } }

      Issue.new(count: scope.count.size, samples: samples)
    end

    def sample_attributes(scope)
      scope.order(Arel.sql('1')).limit(sample_limit).map do |record|
        record.attributes.except('id')
      end
    end
  end
end
