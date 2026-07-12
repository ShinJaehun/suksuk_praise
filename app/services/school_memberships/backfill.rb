module SchoolMemberships
  class Backfill
    Result = Data.define(:created, :skipped, :conflicts)

    def self.call
      created = 0
      skipped = 0
      conflicts = 0

      ClassroomMembership.teacher.includes(:user, classroom: :school).find_each do |classroom_membership|
        result = EnsureForTeacher.call(
          teacher: classroom_membership.user,
          school: classroom_membership.classroom.school
        )
        case result
        when :created then created += 1
        when :conflict then conflicts += 1
        else skipped += 1
        end
      end

      Result.new(created:, skipped:, conflicts:)
    end
  end
end
