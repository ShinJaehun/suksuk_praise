require "rails_helper"

RSpec.describe "Admin teacher school memberships", type: :request do
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

  it "shows school membership and read-only classroom information without assignment inputs" do
    classroom = create(:classroom, school: school, grade: 4, name: "4학년 1반")
    create(:school_membership, user: teacher, school: school)
    create(:classroom_membership, user: teacher, classroom: classroom, role: :teacher)
    sign_in admin

    get edit_admin_teacher_path(teacher), headers: { "Turbo-Frame" => "modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('<turbo-frame id="modal"').size).to eq(1)
    expect(response.body).to match(%r{<option selected="selected" value="#{school.id}">#{school.name}</option>})
    expect(response.body).to include(classroom.name, "담당 학급은 해당 학교의 선생님 관리 화면에서 배정합니다.")
    expect(response.body).to include(school_teachers_path(school))
    expect(response.body).not_to include('name="classroom_ids[]"')
  end

  it "creates a teacher with a school membership and default personal coupons" do
    library_template = create(:coupon_template, created_by: admin, bucket: "library", active: true, title: "칭찬 쿠폰")
    sign_in admin

    post admin_teachers_path, params: { user: valid_teacher_params, school_id: school.id }

    created_teacher = User.teacher.find_by!(email: valid_teacher_params[:email])
    expect(response).to redirect_to(admin_teachers_path)
    expect(created_teacher.school).to eq(school)
    expect(CouponTemplate.personal_for(created_teacher).find_by(title: library_template.title)).to be_present
  end

  it "creates a teacher without a school" do
    sign_in admin

    post admin_teachers_path, params: { user: valid_teacher_params, school_id: "" }

    created_teacher = User.teacher.find_by!(email: valid_teacher_params[:email])
    expect(response).to redirect_to(admin_teachers_path)
    expect(created_teacher.school_membership).to be_nil
  end

  it "rolls back teacher creation for a school id that does not exist" do
    sign_in admin

    expect do
      post admin_teachers_path,
        params: { user: valid_teacher_params, school_id: School.maximum(:id).to_i + 10_000 },
        headers: { "Accept" => Mime[:turbo_stream].to_s }
    end.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body).to include("선택한 학교를 찾을 수 없습니다.")
  end

  it "rolls back teacher creation when default coupon preparation fails" do
    invalid_template = CouponTemplate.new
    invalid_template.errors.add(:title, :blank)
    allow(CouponTemplates::AutoAdopter).to receive(:setup_for_teacher!)
      .and_raise(ActiveRecord::RecordInvalid.new(invalid_template))
    sign_in admin

    expect do
      post admin_teachers_path,
        params: { user: valid_teacher_params, school_id: school.id },
        headers: { "Accept" => Mime[:turbo_stream].to_s }
    end.not_to(change { [User.count, SchoolMembership.count, CouponTemplate.count] })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("선생님 계정의 기본 쿠폰을 준비하지 못했습니다.")
    expect(User.find_by(email: valid_teacher_params[:email])).to be_nil
  end

  it "rolls back the teacher and coupons when school membership validation fails" do
    invalid_membership = SchoolMembership.new
    invalid_membership.errors.add(:base, "학교 소속을 저장하지 못했습니다.")
    allow(SchoolMembership).to receive(:create!)
      .and_raise(ActiveRecord::RecordInvalid.new(invalid_membership))
    sign_in admin

    expect do
      post admin_teachers_path,
        params: { user: valid_teacher_params, school_id: school.id },
        headers: { "Accept" => Mime[:turbo_stream].to_s }
    end.not_to(change { [User.count, SchoolMembership.count, CouponTemplate.count] })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("학교 소속을 저장하지 못했습니다.")
  end

  it "changes and removes a teacher school membership" do
    create(:school_membership, user: teacher, school: school)
    sign_in admin

    patch admin_teacher_path(teacher), params: { school_id: other_school.id }
    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.school).to eq(other_school)

    patch admin_teacher_path(teacher), params: { school_id: "" }
    expect(teacher.reload.school_membership).to be_nil
  end

  it "rejects changing school while classroom assignments remain" do
    classroom = create(:classroom, school: school)
    school_membership = create(:school_membership, user: teacher, school: school)
    classroom_membership = create(:classroom_membership, user: teacher, classroom: classroom, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { school_id: other_school.id },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body).to include("담당 학급을 먼저 모두 해제한 뒤 학교 소속을 변경하거나 삭제해 주세요.")
    expect(teacher.reload.school_membership).to eq(school_membership)
    expect(teacher.school).to eq(school)
    expect(teacher.classroom_memberships.teacher.pluck(:id)).to contain_exactly(classroom_membership.id)
  end

  it "rejects removing school membership while classroom assignments remain" do
    classroom = create(:classroom, school: school)
    school_membership = create(:school_membership, user: teacher, school: school)
    classroom_membership = create(:classroom_membership, user: teacher, classroom: classroom, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { school_id: "" },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body).to include("담당 학급을 먼저 모두 해제한 뒤 학교 소속을 변경하거나 삭제해 주세요.")
    expect(teacher.reload.school_membership).to eq(school_membership)
    expect(teacher.classroom_memberships.teacher.pluck(:id)).to contain_exactly(classroom_membership.id)
  end

  it "keeps a failed school update and its selection in the modal" do
    create(:school_membership, user: teacher, school: school)
    sign_in admin

    patch admin_teacher_path(teacher),
      params: { school_id: School.maximum(:id).to_i + 10_000 },
      headers: { "Accept" => Mime[:turbo_stream].to_s }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('turbo-stream action="replace" target="modal"')
    expect(response.body).to include("선택한 학교를 찾을 수 없습니다.")
    expect(teacher.reload.school).to eq(school)
  end

  it "ignores forged classroom assignment params and preserves memberships" do
    existing_classroom = create(:classroom, school: school)
    forged_classroom = create(:classroom, school: school)
    create(:school_membership, user: teacher, school: school)
    membership = create(:classroom_membership, user: teacher, classroom: existing_classroom, role: :teacher)
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      school_id: school.id,
      classroom_ids: [forged_classroom.id]
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.school).to eq(school)
    expect(teacher.classroom_memberships.teacher.pluck(:id)).to contain_exactly(membership.id)
    expect(teacher.classroom_memberships.teacher.exists?(classroom: forged_classroom)).to eq(false)
  end

  it "ignores user account params while applying a school membership change" do
    original_attributes = teacher.attributes.slice("name", "email", "encrypted_password", "gender", "avatar_key")
    sign_in admin

    patch admin_teacher_path(teacher), params: {
      user: { name: "변조된 이름", email: "changed@example.com", password: "changed-password" },
      school_id: school.id
    }

    expect(response).to redirect_to(admin_teachers_path)
    expect(teacher.reload.attributes.slice(*original_attributes.keys)).to eq(original_attributes)
    expect(teacher.school).to eq(school)
  end

  it "shows assignment summaries as read-only data in the index" do
    classrooms = [
      create(:classroom, school: school, grade: 4, name: "4학년 1반"),
      create(:classroom, school: school, grade: 3, name: "3학년 1반")
    ]
    create(:school_membership, user: teacher, school: school)
    classrooms.each { |classroom| create(:classroom_membership, user: teacher, classroom: classroom, role: :teacher) }
    sign_in admin

    get admin_teachers_path

    expect(response.body).to include(school.name, "3, 4학년", "4학년 1반", "3학년 1반")
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
