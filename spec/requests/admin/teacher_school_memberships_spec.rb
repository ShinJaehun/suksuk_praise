require "rails_helper"

RSpec.describe "Admin teacher school and classroom assignments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) do
    create(
      :user,
      :teacher,
      name: "담당 교사",
      email: "teacher@example.com",
      password: "original-password",
      gender: "male",
      avatar_key: "teacherM01"
    )
  end
  let(:school) { create(:school, name: "가온초등학교") }
  let(:other_school) { create(:school, name: "나래초등학교") }

  it "shows the selected school and classroom groups in the edit modal" do
    classroom = create(:classroom, school: school, name: "4학년 1반")
    other_classroom = create(:classroom, school: other_school, name: "다른 학교 학급")
    create(:school_membership, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: classroom, role: :teacher)
    sign_in admin

    get edit_admin_teacher_path(teacher), headers: { "Turbo-Frame" => "modal" }

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.at_css('[data-controller="teacher-school-classrooms"]')).to be_present
    expect(document.at_css(%(select[name="school_id"] option[value="#{school.id}"][selected]))).to be_present
    expect(document.at_css(%(input[name="classroom_ids[]"][value="#{classroom.id}"][checked]))).to be_present
    expect(document.at_css(%([data-school-id="#{other_school.id}"][hidden]))).to be_present
    expect(document.at_css(%(input[name="classroom_ids[]"][value="#{other_classroom.id}"][disabled]))).to be_present
    expect(response.body).not_to include(school_teachers_path(school))
    expect(response.body).not_to include("담당 학급은 해당 학교의 선생님 관리 화면에서 배정합니다.")
  end

  it "creates a teacher without a school or classrooms" do
    sign_in admin

    post admin_teachers_path, params: {
      user: valid_teacher_params,
      school_id: "",
      classroom_ids: [""]
    }

    created_teacher = User.teacher.find_by!(email: valid_teacher_params[:email])
    expect(response).to redirect_to(admin_teachers_path)
    expect(created_teacher.school_membership).to be_nil
    expect(created_teacher.classroom_memberships.teacher).to be_empty
  end

  it "creates a teacher with a school and no classrooms" do
    sign_in admin

    post admin_teachers_path, params: {
      user: valid_teacher_params,
      school_id: school.id,
      classroom_ids: [""]
    }

    created_teacher = User.teacher.find_by!(email: valid_teacher_params[:email])
    expect(response).to redirect_to(admin_teachers_path)
    expect(created_teacher.school_membership).to have_attributes(school: school, role: "member")
    expect(created_teacher.classroom_memberships.teacher).to be_empty
  end

  it "creates a teacher with a school, classrooms, and default personal coupons" do
    classrooms = create_list(:classroom, 2, school: school)
    library_template = create(:coupon_template, created_by: admin, bucket: "library", active: true, title: "칭찬 쿠폰")
    sign_in admin

    post admin_teachers_path, params: {
      user: valid_teacher_params,
      school_id: school.id,
      classroom_ids: classrooms.map(&:id)
    }

    created_teacher = User.teacher.find_by!(email: valid_teacher_params[:email])
    expect(response).to redirect_to(admin_teachers_path)
    expect(created_teacher.school_membership).to have_attributes(school: school, role: "member")
    expect(created_teacher.classroom_memberships.teacher.pluck(:classroom_id)).to match_array(classrooms.map(&:id))
    expect(CouponTemplate.personal_for(created_teacher).find_by(title: library_template.title)).to be_present
  end

  it "rejects a classroom from another school and rolls back teacher creation" do
    other_classroom = create(:classroom, school: other_school)
    sign_in admin

    expect do
      post admin_teachers_path,
        params: {
          user: valid_teacher_params,
          school_id: school.id,
          classroom_ids: [other_classroom.id]
        },
        headers: { "Accept" => Mime[:turbo_stream].to_s }
    end.not_to change { [User.count, SchoolMembership.count, ClassroomMembership.count, CouponTemplate.count] }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("선택한 학교에 속하지 않은 학급이 포함되어 있습니다.")
  end

  it "rejects missing-school and nonexistent-classroom creation requests" do
    classroom = create(:classroom, school: school)
    missing_id = Classroom.maximum(:id).to_i + 10_000
    sign_in admin

    [
      { school_id: "", classroom_ids: [classroom.id], message: "학교 소속이 없으면 담당 학급을 지정할 수 없습니다." },
      { school_id: school.id, classroom_ids: [missing_id], message: "선택한 학급을 찾을 수 없습니다." }
    ].each do |invalid_params|
      expect do
        post admin_teachers_path,
          params: { user: valid_teacher_params }.merge(invalid_params.except(:message)),
          headers: { "Accept" => Mime[:turbo_stream].to_s }
      end.not_to change { [User.count, SchoolMembership.count, ClassroomMembership.count, CouponTemplate.count] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(invalid_params[:message])
    end
  end

  it "rolls back teacher creation when an assignment cannot be created" do
    classroom = create(:classroom, school: school)
    invalid_membership = ClassroomMembership.new
    invalid_membership.errors.add(:base, "담당 학급을 저장하지 못했습니다.")
    allow(ClassroomMembership).to receive(:create!)
      .and_raise(ActiveRecord::RecordInvalid.new(invalid_membership))
    sign_in admin

    expect do
      post admin_teachers_path,
        params: {
          user: valid_teacher_params,
          school_id: school.id,
          classroom_ids: [classroom.id]
        },
        headers: { "Accept" => Mime[:turbo_stream].to_s }
    end.not_to change { [User.count, SchoolMembership.count, ClassroomMembership.count, CouponTemplate.count] }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("담당 학급을 저장하지 못했습니다.")
  end

  it "rolls back the user, coupons, membership, and assignments when coupon preparation fails" do
    classroom = create(:classroom, school: school)
    invalid_template = CouponTemplate.new
    invalid_template.errors.add(:title, :blank)
    allow(CouponTemplates::AutoAdopter).to receive(:setup_for_teacher!)
      .and_raise(ActiveRecord::RecordInvalid.new(invalid_template))
    sign_in admin

    expect do
      post admin_teachers_path,
        params: {
          user: valid_teacher_params,
          school_id: school.id,
          classroom_ids: [classroom.id]
        },
        headers: { "Accept" => Mime[:turbo_stream].to_s }
    end.not_to change { [User.count, SchoolMembership.count, ClassroomMembership.count, CouponTemplate.count] }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("선생님 계정의 기본 쿠폰을 준비하지 못했습니다.")
  end

  it "changes classroom assignments in the same school while preserving the manager role" do
    removed_classroom = create(:classroom, school: school)
    kept_classroom = create(:classroom, school: school)
    added_classroom = create(:classroom, school: school)
    membership = create(:school_membership, :manager, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: removed_classroom, role: :teacher)
    kept_membership = create(:classroom_membership, user: teacher, classroom: kept_classroom, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: school.id,
      classroom_ids: [kept_classroom.id, added_classroom.id]
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(membership.reload).to be_manager
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to contain_exactly(kept_classroom.id, added_classroom.id)
    expect(teacher.classroom_memberships.teacher.find_by(classroom: kept_classroom)).to eq(kept_membership)
  end

  it "changes school and classroom assignments atomically and resets the manager role" do
    old_classroom = create(:classroom, school: school)
    new_classrooms = create_list(:classroom, 2, school: other_school)
    membership = create(:school_membership, :manager, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: old_classroom, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: other_school.id,
      classroom_ids: new_classrooms.map(&:id)
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(membership.reload).to have_attributes(school: other_school, role: "member")
    expect(teacher.classroom_memberships.teacher.pluck(:classroom_id)).to match_array(new_classrooms.map(&:id))
  end

  it "removes every teacher classroom assignment and the school membership" do
    classroom = create(:classroom, school: school)
    create(:school_membership, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: classroom, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher), params: { school_id: "", classroom_ids: [""] }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.school_membership).to be_nil
    expect(teacher.classroom_memberships.teacher).to be_empty
  end

  it "rejects invalid final school and classroom combinations without partial changes" do
    existing_classroom = create(:classroom, school: school)
    other_classroom = create(:classroom, school: other_school)
    membership = create(:school_membership, :manager, user: teacher, school: school)
    assignment = create(:classroom_membership, user: teacher, classroom: existing_classroom, role: :teacher)
    missing_id = Classroom.maximum(:id).to_i + 10_000
    sign_in admin

    [
      { school_id: "", classroom_ids: [existing_classroom.id], message: "학교 소속이 없으면 담당 학급을 지정할 수 없습니다." },
      { school_id: school.id, classroom_ids: [other_classroom.id], message: "선택한 학교에 속하지 않은 학급이 포함되어 있습니다." },
      { school_id: school.id, classroom_ids: [missing_id], message: "선택한 학급을 찾을 수 없습니다." }
    ].each do |invalid_params|
      patch admin_teacher_path(teacher),
        params: invalid_params.except(:message),
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(invalid_params[:message])
      expect(teacher.reload.school_membership).to eq(membership)
      expect(teacher.classroom_memberships.teacher.pluck(:id)).to contain_exactly(assignment.id)
    end
  end

  it "does not interpret a missing classroom selection as an explicit full removal" do
    existing_classroom = create(:classroom, school: school)
    membership = create(:school_membership, user: teacher, school: school)
    assignment = create(:classroom_membership, user: teacher, classroom: existing_classroom, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { school_id: other_school.id },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("학교와 담당 학급의 최종 상태를 함께 선택해 주세요.")
    expect(teacher.reload.school_membership).to eq(membership)
    expect(teacher.classroom_memberships.teacher.pluck(:id)).to contain_exactly(assignment.id)
  end

  it "rolls back removed assignments and the school change when a new assignment fails" do
    old_classroom = create(:classroom, school: school)
    new_classroom = create(:classroom, school: other_school)
    membership = create(:school_membership, :manager, user: teacher, school: school)
    assignment = create(:classroom_membership, user: teacher, classroom: old_classroom, role: :teacher)
    invalid_membership = ClassroomMembership.new
    invalid_membership.errors.add(:base, "담당 학급을 저장하지 못했습니다.")
    allow(ClassroomMembership).to receive(:create!)
      .and_raise(ActiveRecord::RecordInvalid.new(invalid_membership))
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { school_id: other_school.id, classroom_ids: [new_classroom.id] },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(membership.reload).to have_attributes(school: school, role: "manager")
    expect(teacher.classroom_memberships.teacher.pluck(:id)).to contain_exactly(assignment.id)
  end

  it "ignores forged account and school membership role params" do
    classroom = create(:classroom, school: school)
    original_attributes = teacher.attributes.slice("name", "email", "encrypted_password", "gender", "avatar_key", "role")
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      user: { name: "변조된 이름", email: "changed@example.com", password: "changed-password", role: "admin" },
      school_id: school.id,
      classroom_ids: [classroom.id],
      school_membership: { role: "manager" }
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.attributes.slice(*original_attributes.keys)).to eq(original_attributes)
    expect(teacher.school_membership).to have_attributes(school: school, role: "member")
    expect(teacher.classroom_memberships.teacher.exists?(classroom: classroom)).to eq(true)
  end

  it "rejects a non-teacher target without changing it" do
    student = create(:user, :student)
    original_attributes = student.attributes
    sign_in admin

    patch admin_teacher_path(student),
      params: { school_id: school.id, classroom_ids: [create(:classroom, school: school).id] },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("선생님 계정만 학교와 담당 학급을 변경할 수 있습니다.")
    expect(student.reload.attributes).to eq(original_attributes)
    expect(student.school_membership).to be_nil
    expect(student.classroom_memberships).to be_empty
  end

  def valid_teacher_params
    {
      name: "새 교사",
      email: "new-school-teacher@example.com",
      password: "password123",
      gender: "female",
      avatar_key: "teacherF01"
    }
  end
end
