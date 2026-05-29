require "rails_helper"

RSpec.describe "Classroom teacher assignments", type: :request do
  let(:classroom) { create(:classroom) }
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: "담당 교사") }
  let(:other_teacher) { create(:user, :teacher, name: "추가 교사") }

  describe "GET /classrooms/:id/edit" do
    it "does not show teacher assignment controls to an admin" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      other_teacher
      sign_in admin

      get edit_classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("담당 선생님 배정")
      expect(response.body).not_to include("classroom[teacher_ids][]")
    end

    it "does not show teacher assignment controls to a teacher" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      sign_in teacher

      get edit_classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("담당 선생님 배정")
      expect(response.body).not_to include("classroom[teacher_ids][]")
    end
  end

  describe "PATCH /classrooms/:id" do
    it "allows an admin to assign a teacher" do
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [other_teacher.id.to_s])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.exists?(user: other_teacher)).to eq(true)
    end

    it "allows an admin to remove a teacher assignment" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [other_teacher.id.to_s])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(false)
      expect(classroom.classroom_memberships.teacher.exists?(user: other_teacher)).to eq(true)
    end

    it "does not change student or admin memberships when syncing teacher assignments" do
      student = create(:user, :student)
      student_membership = create(:classroom_membership, classroom: classroom, user: student, role: "student")
      admin_membership = create(:classroom_membership, classroom: classroom, user: admin, role: "teacher")
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [other_teacher.id.to_s])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(ClassroomMembership.exists?(student_membership.id)).to eq(true)
      expect(ClassroomMembership.exists?(admin_membership.id)).to eq(true)
      expect(student_membership.reload.role).to eq("student")
      expect(admin_membership.reload.role).to eq("teacher")
    end

    it "ignores teacher assignment params from a teacher" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      create(:classroom_membership, classroom: classroom, user: other_teacher, role: "teacher")
      sign_in teacher

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [teacher.id.to_s])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(true)
      expect(classroom.classroom_memberships.teacher.exists?(user: other_teacher)).to eq(true)
    end
  end

  def classroom_update_params
    {
      name: classroom.name,
      daily_compliment_king_enabled: classroom.daily_compliment_king_enabled ? "1" : "0",
      weekly_compliment_king_enabled: classroom.weekly_compliment_king_enabled ? "1" : "0",
      monthly_compliment_king_enabled: classroom.monthly_compliment_king_enabled ? "1" : "0",
      message_policy: classroom.message_policy
    }
  end
end
