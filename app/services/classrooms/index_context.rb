class Classrooms::IndexContext
  def initialize(classrooms_scope:)
    @classrooms_scope = classrooms_scope
  end

  def classrooms
    @classrooms ||= @classrooms_scope.includes(:school).order(created_at: :desc)
  end

  def teacher_counts
    @teacher_counts ||= teacher_memberships.group(:classroom_id).count
  end

  def teacher_previews
    @teacher_previews ||= classroom_membership_previews(
      role: "teacher",
      user_role: "teacher",
      limit_per_classroom: 3
    )
  end

  def student_counts
    @student_counts ||= ClassroomMembership
      .where(classroom_id: classroom_ids, role: "student", status: "active")
      .group(:classroom_id)
      .count
  end

  def student_previews
    @student_previews ||= classroom_membership_previews(
      role: "student",
      status: "active",
      limit_per_classroom: 5
    )
  end

  private

  def classroom_ids
    @classroom_ids ||= classrooms.map(&:id)
  end

  def teacher_memberships
    ClassroomMembership
      .joins(:user)
      .where(classroom_id: classroom_ids, role: "teacher", users: { role: "teacher", active: true })
  end

  def classroom_membership_previews(role:, limit_per_classroom:, user_role: nil, status: nil)
    return {} if classroom_ids.empty?

    membership_scope = ClassroomMembership.where(classroom_id: classroom_ids, role: role)
    membership_scope = membership_scope.where(status: status) if status
    membership_scope = membership_scope.joins(:user).where(users: { role: user_role }) if user_role
    membership_scope = membership_scope.where(users: { active: true }) if user_role == "teacher"

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
end
