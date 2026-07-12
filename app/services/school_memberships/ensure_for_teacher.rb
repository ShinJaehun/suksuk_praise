module SchoolMemberships
  class EnsureForTeacher
    class << self
      def call(teacher:, school:)
        return :skipped unless teacher&.teacher? && school

        membership_result = result_for(teacher.school_membership, school)
        return membership_result if membership_result

        SchoolMembership.create!(user: teacher, school: school, role: :member)
        :created
      rescue ActiveRecord::RecordNotUnique
        membership = SchoolMembership.find_by(user_id: teacher.id)
        raise unless membership

        result_for(membership, school)
      end

      private

      def result_for(membership, school)
        return unless membership

        membership.school_id == school.id ? :existing : :conflict
      end
    end
  end
end
