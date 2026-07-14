require "rails_helper"

RSpec.describe "School teachers", type: :request do
  let(:school) { create(:school, name: "아라초등학교") }
  let(:other_school) { create(:school, name: "다른초등학교") }
  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:school_membership, :manager, school: school, user: create(:user, :teacher, name: "학교 관리자")).user }
  let(:member) { create(:school_membership, school: school, user: create(:user, :teacher, name: "일반 선생님")).user }
  let(:other_manager) { create(:school_membership, :manager, school: other_school, user: create(:user, :teacher)).user }

  describe "GET /schools/:school_id/teachers" do
    it "allows an admin and the school manager to view school teachers" do
      classroom = create(:classroom, school: school, grade: 4, name: "4학년 1반")
      other_classroom = create(:classroom, school: other_school, name: "다른 학교 학급")
      unassigned_teacher = create(:user, :teacher, name: "미소속 선생님")
      create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
      create(:classroom_membership, classroom: other_classroom, user: manager, role: :teacher)
      other_school_teacher = create(:school_membership, school: other_school, user: create(:user, :teacher, name: "다른 학교 선생님")).user
      student = create(:user, :student, name: "학생")
      school_member = member

      [admin, manager].each do |actor|
        sign_in actor

        get school_teachers_path(school)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("선생님 관리", "소속 선생님과 담당 교실을 관리합니다.")
        expect(response.body).to include(manager.name, manager.email, "학교 관리자", "4학년 1반", "담당 1개", "4학년")
        expect(response.body).to include(school_member.name, school_member.email, "일반 구성원")
        expect(response.body).to include(new_school_teacher_path(school))
        expect(response.body).to include(edit_school_teacher_path(school, manager))
        expect(response.body).to include(edit_school_teacher_path(school, school_member))
        expect(response.body).not_to include(other_school_teacher.name)
        expect(response.body).not_to include(unassigned_teacher.name)
        expect(response.body).not_to include(student.name)
        expect(response.body).not_to include(other_classroom.name)
      end
    end

    it "shows an empty state" do
      sign_in admin

      get school_teachers_path(school)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("등록된 선생님이 없습니다.")
      expect(response.body).to include(new_school_teacher_path(school))
    end

    it "blocks members, other school managers, students, and guests" do
      sign_in member
      get school_teachers_path(school)
      expect(response).to redirect_to(root_path)

      sign_in other_manager
      get school_teachers_path(school)
      expect(response).to have_http_status(:not_found)

      sign_in create(:user, :student)
      get school_teachers_path(school)
      expect(response).to have_http_status(:not_found)

      sign_out :user
      get school_teachers_path(school)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /schools/:school_id/teachers" do
    it "creates a member teacher for the URL school as an admin or manager" do
      library_template = create(:coupon_template, created_by: admin, bucket: "library", active: true, title: "기본 쿠폰")

      [admin, manager].each_with_index do |actor, index|
        sign_in actor
        email = "school-teacher-#{index}@example.com"

        post school_teachers_path(school), params: {
          user: valid_teacher_params(email: email),
          school_id: other_school.id
        }

        created_teacher = User.teacher.find_by!(email: email)
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(school_teachers_path(school))
        expect(created_teacher.role).to eq("teacher")
        expect(created_teacher.school_membership).to have_attributes(school: school, role: "member")
        expect(CouponTemplate.personal_for(created_teacher).find_by(title: library_template.title)).to be_present
      end
    end

    it "rolls back user, coupons, and membership on validation failure" do
      sign_in manager

      expect do
        post school_teachers_path(school),
          params: { user: valid_teacher_params(name: "", email: "invalid-school-teacher@example.com") },
          headers: { "Accept" => Mime[:turbo_stream].to_s }
      end.not_to(change { [User.count, SchoolMembership.count, CouponTemplate.count] })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('turbo-stream action="replace" target="modal"')
      expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
      expect(response.body).to include(%(value="invalid-school-teacher@example.com"))
      expect(response.body).to include('<option selected="selected" value="female">여자</option>')
      expect(response.body).not_to include('name="school_id"')
    end

    it "rolls back user and membership when default coupon creation fails" do
      actor = manager
      allow(CouponTemplates::AutoAdopter).to receive(:setup_for_teacher!)
        .and_raise(ActiveRecord::RecordInvalid.new(CouponTemplate.new.tap { |template| template.errors.add(:title, :blank) }))
      sign_in actor

      expect do
        post school_teachers_path(school),
          params: { user: valid_teacher_params(email: "coupon-failure@example.com") },
          headers: { "Accept" => Mime[:turbo_stream].to_s }
      end.not_to(change { [User.count, SchoolMembership.count, CouponTemplate.count] })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("선생님 계정의 기본 쿠폰을 준비하지 못했습니다.")
      expect(User.find_by(email: "coupon-failure@example.com")).to be_nil
    end

    it "blocks direct posts outside the allowed school scope" do
      [other_manager, member, create(:user, :student)].each do |actor|
        sign_in actor

        expect do
          post school_teachers_path(school), params: { user: valid_teacher_params(email: "blocked-#{actor.id}@example.com") }
        end.not_to change { User.teacher.count }
      end
    end

    it "requires authentication" do
      post school_teachers_path(school), params: { user: valid_teacher_params(email: "guest@example.com") }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "PATCH /schools/:school_id/teachers/:id" do
    it "adds and removes only the school's classroom assignments" do
      first_classroom = create(:classroom, school: school, name: "1반")
      second_classroom = create(:classroom, school: school, name: "2반")
      other_classroom = create(:classroom, school: other_school, name: "다른 학교")
      create(:classroom_membership, classroom: first_classroom, user: member, role: :teacher)
      create(:classroom_membership, classroom: other_classroom, user: member, role: :teacher)
      membership = member.school_membership
      sign_in manager

      patch school_teacher_path(school, member), params: { classroom_ids: [second_classroom.id] }

      expect(response).to redirect_to(school_teachers_path(school))
      expect(member.reload.school_membership).to eq(membership)
      expect(membership.reload).to be_member
      expect(member.classroom_memberships.teacher.where(classroom: first_classroom)).to be_empty
      expect(member.classroom_memberships.teacher.exists?(classroom: second_classroom)).to eq(true)
      expect(member.classroom_memberships.teacher.exists?(classroom: other_classroom)).to eq(true)

      patch school_teacher_path(school, member), params: { classroom_ids: [""] }

      expect(response).to redirect_to(school_teachers_path(school))
      expect(member.classroom_memberships.teacher.where(classroom: [first_classroom, second_classroom])).to be_empty
      expect(member.classroom_memberships.teacher.exists?(classroom: other_classroom)).to eq(true)
    end

    it "keeps manager role while updating assignments" do
      classroom = create(:classroom, school: school)
      sign_in admin

      patch school_teacher_path(school, manager), params: { classroom_ids: [classroom.id] }

      expect(response).to redirect_to(school_teachers_path(school))
      expect(manager.reload.school_membership).to be_manager
      expect(manager.classroom_memberships.teacher.exists?(classroom: classroom)).to eq(true)
    end

    it "rejects another school or malformed classroom id without partial changes" do
      existing_classroom = create(:classroom, school: school)
      valid_classroom = create(:classroom, school: school)
      other_classroom = create(:classroom, school: other_school)
      create(:classroom_membership, classroom: existing_classroom, user: member, role: :teacher)
      sign_in manager

      patch school_teacher_path(school, member),
        params: { classroom_ids: [valid_classroom.id, other_classroom.id] },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('turbo-stream action="replace" target="modal"')
      expect(response.body).to include("선택한 교실을 찾을 수 없습니다.")
      expect(member.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(existing_classroom.id)

      patch school_teacher_path(school, member), params: { classroom_ids: ["abc"] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("<!DOCTYPE html>")
      expect(member.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(existing_classroom.id)
    end

    it "returns 404 when editing users outside the URL school" do
      unassigned_teacher = create(:user, :teacher)
      other_teacher = create(:school_membership, school: other_school, user: create(:user, :teacher)).user
      student = create(:user, :student)

      [unassigned_teacher, other_teacher, student].each do |user|
        sign_in manager

        get edit_school_teacher_path(school, user)

        expect(response).to have_http_status(:not_found)
      end
    end

    it "returns 404 when updating users outside the URL school" do
      unassigned_teacher = create(:user, :teacher)
      other_teacher = create(:school_membership, school: other_school, user: create(:user, :teacher)).user
      student = create(:user, :student)

      [unassigned_teacher, other_teacher, student].each do |user|
        sign_in manager

        patch school_teacher_path(school, user), params: { classroom_ids: [""] }

        expect(response).to have_http_status(:not_found)
      end
    end

    it "blocks direct patches outside the allowed school scope" do
      classroom = create(:classroom, school: school)

      sign_in other_manager
      patch school_teacher_path(school, member), params: { classroom_ids: [classroom.id] }
      expect(response).to have_http_status(:not_found)

      sign_in member
      patch school_teacher_path(school, member), params: { classroom_ids: [classroom.id] }
      expect(response).to redirect_to(root_path)
    end
  end

  def valid_teacher_params(name: "새 교사", email:)
    {
      name: name,
      email: email,
      password: "password123",
      password_confirmation: "password123",
      gender: "female",
      avatar_key: "teacherF01"
    }
  end
end
