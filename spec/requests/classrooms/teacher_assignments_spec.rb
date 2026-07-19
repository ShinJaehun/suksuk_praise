require "rails_helper"

RSpec.describe "Classroom teacher assignment boundary", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:school) { create(:school) }
  let(:manager) { create(:user, :teacher) }
  let(:teacher) { create(:user, :teacher) }

  before do
    create(:school_membership, :manager, school: school, user: manager)
  end

  describe "classroom forms" do
    it "does not show teacher assignment inputs on the admin new or edit form" do
      classroom = create(:classroom, school: school)
      sign_in admin

      get new_classroom_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="classroom[teacher_ids][]"')

      get edit_classroom_path(classroom)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="classroom[teacher_ids][]"')
    end

    it "does not show teacher assignment inputs on the manager new or edit form" do
      classroom = create(:classroom, school: school)
      sign_in manager

      get new_classroom_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="classroom[teacher_ids][]"')

      get edit_classroom_path(classroom)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="classroom[teacher_ids][]"')
    end

    it "does not show teacher assignment inputs to an assigned teacher" do
      classroom = create(:classroom, school: school)
      create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
      sign_in teacher

      get edit_classroom_path(classroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="classroom[teacher_ids][]"')
    end
  end

  describe "POST /classrooms" do
    it "ignores forged teacher_ids from an admin" do
      create(:school_membership, school: school, user: teacher)
      sign_in admin

      expect do
        post classrooms_path, params: {
          classroom: { name: "관리자 생성 학급", school_id: school.id, grade: 2, teacher_ids: [teacher.id] }
        }
      end.not_to change { ClassroomMembership.teacher.count }

      classroom = Classroom.find_by!(name: "관리자 생성 학급")
      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher).to be_empty
    end

    it "ignores forged teacher_ids from a manager" do
      sign_in manager

      expect do
        post classrooms_path, params: {
          classroom: { name: "관리자 생성 학급", grade: 3, teacher_ids: [manager.id] }
        }
      end.not_to change { ClassroomMembership.teacher.count }

      classroom = Classroom.find_by!(name: "관리자 생성 학급")
      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher).to be_empty
    end
  end

  describe "PATCH /classrooms/:id" do
    it "ignores forged teacher_ids from an admin" do
      classroom = create(:classroom, school: school)
      other_teacher = create(:school_membership, school: school).user
      membership = create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
      sign_in admin

      patch classroom_path(classroom), params: {
        classroom: { name: "변경 학급", grade: 4, teacher_ids: [other_teacher.id] }
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.pluck(:id)).to contain_exactly(membership.id)
    end

    it "ignores forged teacher_ids from a manager" do
      classroom = create(:classroom, school: school)
      other_teacher = create(:school_membership, school: school).user
      membership = create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
      sign_in manager

      patch classroom_path(classroom), params: {
        classroom: { name: "변경 학급", grade: 4, teacher_ids: [other_teacher.id] }
      }

      expect(response).to redirect_to(classroom_path(classroom))
      expect(classroom.classroom_memberships.teacher.pluck(:id)).to contain_exactly(membership.id)
    end
  end
end
