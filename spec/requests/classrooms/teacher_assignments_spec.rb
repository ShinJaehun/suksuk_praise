require "rails_helper"

RSpec.describe "Classroom teacher assignments", type: :request do
  let(:classroom) { create(:classroom) }
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher, name: "담당 교사") }
  let(:other_teacher) { create(:user, :teacher, name: "추가 교사") }

  describe "GET /classrooms/:id/edit" do
    it "shows teacher assignment controls to an admin" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      same_school_teacher = create(:school_membership, school: classroom.school, user: create(:user, :teacher, name: "같은 학교 교사")).user
      same_school_manager = create(:school_membership, :manager, school: classroom.school, user: create(:user, :teacher, name: "같은 학교 관리자")).user
      other_school_teacher = create(:school_membership, school: create(:school), user: create(:user, :teacher, name: "다른 학교 교사")).user
      unassigned_teacher = create(:user, :teacher, name: "미소속 교사")
      admin_user = create(:user, :admin, name: "관리자 후보 아님")
      student = create(:user, :student, name: "학생 후보 아님")
      sign_in admin

      get edit_classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("담당 선생님 배정")
      expect(response.body).to include("이 학교에 소속된 선생님만 표시됩니다.")
      expect(response.body).to include("classroom[teacher_ids][]")
      expect(response.body).to include(same_school_teacher.name)
      expect(response.body).to include(same_school_manager.name)
      expect(response.body).not_to include(other_school_teacher.name)
      expect(response.body).not_to include(unassigned_teacher.name)
      expect(response.body).not_to include(admin_user.name)
      expect(response.body).not_to include(student.name)
    end

    it "shows teacher assignment controls to a manager for their school" do
      school = create(:school)
      classroom.update!(school: school)
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)
      sign_in manager

      get edit_classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("담당 선생님 배정")
      expect(response.body).to include("classroom[teacher_ids][]")
      expect(response.body).to include(manager.name)
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
      school = create(:school)
      classroom.update!(school: school)
      create(:school_membership, school: school, user: other_teacher)
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [other_teacher.id.to_s])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.exists?(user: other_teacher)).to eq(true)
      expect(other_teacher.reload.school_membership).to have_attributes(school: school, role: "member")
    end

    it "allows a manager to assign a member teacher in their school" do
      school = create(:school)
      classroom.update!(school: school)
      manager = create(:user, :teacher)
      member_teacher = create(:school_membership, school: school).user
      create(:school_membership, :manager, school: school, user: manager)
      sign_in manager

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [member_teacher.id.to_s])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.pluck(:user_id)).to contain_exactly(member_teacher.id)
    end

    it "allows a manager to assign another manager in their school" do
      school = create(:school)
      classroom.update!(school: school)
      manager = create(:user, :teacher)
      other_manager = create(:school_membership, :manager, school: school).user
      create(:school_membership, :manager, school: school, user: manager)
      sign_in manager

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [other_manager.id.to_s])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.pluck(:user_id)).to contain_exactly(other_manager.id)
    end

    it "rejects manager assignment of teachers outside their school without partial changes" do
      school = create(:school)
      other_school = create(:school)
      classroom.update!(name: "기존 교실", school: school, grade: 2)
      manager = create(:user, :teacher)
      existing_teacher = create(:school_membership, school: school).user
      other_teacher = create(:school_membership, school: other_school).user
      create(:school_membership, :manager, school: school, user: manager)
      create(:classroom_membership, classroom: classroom, user: existing_teacher, role: :teacher)
      sign_in manager

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(
          name: "변경되면 안 됨",
          grade: 5,
          teacher_ids: [existing_teacher.id, other_teacher.id]
        )
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("해당 학교에 소속된 선생님만 담당 교사로 지정할 수 있습니다.")
      expect(classroom.reload).to have_attributes(name: "기존 교실", grade: 2)
      expect(classroom.classroom_memberships.teacher.pluck(:user_id)).to contain_exactly(existing_teacher.id)
    end

    it "rejects manager assignment of an unassigned teacher without creating a school membership" do
      school = create(:school)
      classroom.update!(school: school)
      manager = create(:user, :teacher)
      unassigned_teacher = create(:user, :teacher)
      create(:school_membership, :manager, school: school, user: manager)
      sign_in manager

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [unassigned_teacher.id])
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(unassigned_teacher.reload.school_membership).to be_nil
      expect(classroom.classroom_memberships.teacher).to be_empty
    end

    it "rejects admin assignment of an unassigned teacher without creating a school membership" do
      school = create(:school)
      classroom.update!(name: "기존 교실", school: school, grade: 2)
      existing_teacher = create(:school_membership, school: school).user
      unassigned_teacher = create(:user, :teacher)
      create(:classroom_membership, classroom: classroom, user: existing_teacher, role: :teacher)
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(
          name: "변경되면 안 됨",
          grade: 5,
          teacher_ids: [existing_teacher.id, unassigned_teacher.id]
        )
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("해당 학교에 소속된 선생님만 담당 교사로 지정할 수 있습니다.")
      expect(classroom.reload).to have_attributes(name: "기존 교실", grade: 2, school: school)
      expect(classroom.classroom_memberships.teacher.pluck(:user_id)).to contain_exactly(existing_teacher.id)
      expect(unassigned_teacher.reload.school_membership).to be_nil
    end

    it "rejects manager assignment of a student" do
      school = create(:school)
      classroom.update!(school: school)
      manager = create(:user, :teacher)
      student = create(:user, :student)
      create(:school_membership, :manager, school: school, user: manager)
      sign_in manager

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [student.id])
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("선택한 담당 교사를 찾을 수 없습니다.")
      expect(classroom.classroom_memberships.teacher).to be_empty
    end

    it "allows an admin to assign multiple teachers" do
      school = create(:school)
      classroom.update!(school: school)
      create(:school_membership, school: school, user: teacher)
      create(:school_membership, school: school, user: other_teacher)
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(
          teacher_ids: [teacher.id.to_s, teacher.id.to_s, other_teacher.id.to_s]
        )
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.pluck(:user_id))
        .to contain_exactly(teacher.id, other_teacher.id)
      expect(SchoolMembership.where(school: school, user: [teacher, other_teacher]).count).to eq(2)
    end

    it "allows an admin to remove a teacher assignment" do
      school = create(:school)
      classroom.update!(school: school)
      school_membership = create(:school_membership, school: school, user: teacher)
      create(:school_membership, school: school, user: other_teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [other_teacher.id.to_s])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(false)
      expect(classroom.classroom_memberships.teacher.exists?(user: other_teacher)).to eq(true)
      expect(school_membership.reload).to be_member
      expect(school_membership).to be_persisted
    end

    it "preserves an existing manager when assigning and keeps membership after removal" do
      school = create(:school)
      classroom.update!(school: school)
      membership = create(:school_membership, :manager, school: school, user: teacher)
      sign_in admin

      patch classroom_path(classroom), params: { classroom: classroom_update_params.merge(teacher_ids: [teacher.id.to_s]) }
      patch classroom_path(classroom), params: { classroom: classroom_update_params.merge(teacher_ids: [""]) }

      expect(membership.reload).to be_manager
    end

    it "rejects members and managers from another school without partial changes" do
      original_school = create(:school)
      target_school = create(:school)
      classroom.update!(name: "기존 교실", school: target_school, grade: 2)
      existing_teacher = create(:user, :teacher)
      create(:school_membership, school: target_school, user: existing_teacher)
      create(:classroom_membership, classroom: classroom, user: existing_teacher, role: :teacher)

      conflicting_teachers = [create(:school_membership, school: original_school).user, create(:school_membership, :manager, school: original_school).user]
      sign_in admin

      conflicting_teachers.each do |conflicting_teacher|
        patch classroom_path(classroom), params: {
          classroom: classroom_update_params.merge(
            name: "변경되면 안 됨",
            grade: 5,
            school_id: target_school.id,
            teacher_ids: [existing_teacher.id, conflicting_teacher.id]
          )
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("해당 학교에 소속된 선생님만 담당 교사로 지정할 수 있습니다.")
        expect(classroom.reload).to have_attributes(name: "기존 교실", grade: 2, school: target_school)
        expect(classroom.classroom_memberships.teacher.pluck(:user_id)).to contain_exactly(existing_teacher.id)
      end
    end

    it "allows the same teacher to remain assigned across classrooms in one school" do
      school = create(:school)
      classroom.update!(school: school)
      other_classroom = create(:classroom, school: school)
      create(:school_membership, school: school, user: teacher)
      sign_in admin

      [classroom, other_classroom].each do |record|
        patch classroom_path(record), params: { classroom: classroom_update_params.merge(name: record.name, teacher_ids: [teacher.id]) }
        expect(response).to redirect_to(classroom_path(record))
      end

      expect(teacher.classroom_memberships.teacher.count).to eq(2)
      expect(SchoolMembership.where(user: teacher).count).to eq(1)
    end

    it "keeps teacher assignments when teacher_ids is not submitted" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      school = create(:school)
      create(:school_membership, school: school, user: teacher)
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(school_id: school.id, grade: 4)
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(true)
      expect(classroom.reload.school).to eq(school)
      expect(classroom.grade).to eq(4)
    end

    it "removes all teacher assignments when an admin explicitly submits the blank checkbox value" do
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [""])
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher).to be_empty
    end

    it "rejects a teacher id that does not exist without changing the classroom" do
      original_school = create(:school)
      other_school = create(:school)
      classroom.update!(name: "기존 교실", school: original_school, grade: 2)
      create(:school_membership, school: original_school, user: teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      missing_id = User.maximum(:id).to_i + 10_000
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(
          name: "변경된 교실",
          school_id: other_school.id,
          grade: 5,
          teacher_ids: [missing_id.to_s]
        )
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("선택한 담당 교사를 찾을 수 없습니다.")
      expect(classroom.reload).to have_attributes(name: "기존 교실", school: original_school, grade: 2)
      expect(classroom.classroom_memberships.teacher.pluck(:user_id)).to eq([teacher.id])
    end

    it "rejects a non-teacher user id without changing assignments" do
      student = create(:user, :student)
      create(:school_membership, school: classroom.school, user: teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(teacher_ids: [student.id.to_s])
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("선택한 담당 교사를 찾을 수 없습니다.")
      expect(classroom.classroom_memberships.teacher.pluck(:user_id)).to eq([teacher.id])
    end

    it "rejects mixed valid and missing teacher ids without partially applying them" do
      create(:school_membership, school: classroom.school, user: teacher)
      create(:school_membership, school: classroom.school, user: other_teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      missing_id = User.maximum(:id).to_i + 10_000
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: classroom_update_params.merge(
          teacher_ids: [other_teacher.id.to_s, missing_id.to_s]
        )
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(classroom.classroom_memberships.teacher.pluck(:user_id)).to eq([teacher.id])
      expect(classroom.classroom_memberships.teacher.exists?(user: other_teacher)).to eq(false)
    end

    it "rejects malformed, zero, negative, decimal, and whitespace-padded teacher ids" do
      create(:school_membership, school: classroom.school, user: teacher)
      create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
      sign_in admin

      ["abc", "1abc", "0", "-1", "1.5", " #{other_teacher.id}"].each do |invalid_id|
        patch classroom_path(classroom), params: {
          classroom: classroom_update_params.merge(teacher_ids: [invalid_id])
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("선택한 담당 교사를 찾을 수 없습니다.")
        expect(classroom.reload.classroom_memberships.teacher.pluck(:user_id)).to eq([teacher.id])
      end
    end

    it "does not change student or admin memberships when syncing teacher assignments" do
      student = create(:user, :student)
      student_membership = create(:classroom_membership, classroom: classroom, user: student, role: "student")
      admin_membership = create(:classroom_membership, classroom: classroom, user: admin, role: "teacher")
      create(:school_membership, school: classroom.school, user: other_teacher)
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

  describe "POST /classrooms" do
    it "does not create a classroom with teacher assignment params" do
      missing_id = User.maximum(:id).to_i + 10_000
      sign_in admin

      expect do
        post classrooms_path, params: {
          classroom: {
            name: "생성되면 안 되는 교실",
            teacher_ids: [missing_id.to_s]
          }
        }
      end.not_to change(Classroom, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("교실을 만든 뒤 관리 화면에서 담당 선생님을 배정해 주세요.")
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
