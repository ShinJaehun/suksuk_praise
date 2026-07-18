require 'rails_helper'

RSpec.describe 'Classroom organization settings', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:teacher) { create(:user, :teacher) }
  let(:school) { create(:school, name: '새싹초등학교') }

  it 'shows school and grade fields only to an admin' do
    sign_in admin
    get new_classroom_path

    expect(response.body).to include('name="classroom[school_id]"')
    expect(response.body).to include('name="classroom[grade]"')
    expect(response.body).to include('학교 선택')
    expect(response.body).to include('학년 선택')

    sign_in teacher
    get new_classroom_path

    expect(response.body).not_to include('name="classroom[school_id]"')
    expect(response.body).not_to include('name="classroom[grade]"')
  end

  it 'shows a manager their whole school classrooms without other schools' do
    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: school, user: manager)
    assigned_classroom = create(:classroom, school: school, name: '담당 학급')
    unassigned_classroom = create(:classroom, school: school, name: '미담당 학급')
    create(:classroom, school: create(:school), name: '다른 학교 학급')
    create(:classroom_membership, classroom: assigned_classroom, user: manager, role: :teacher)
    sign_in manager

    get classrooms_path

    expect(response.body).to include(
      '학교 전체 학급',
      '담당 학급',
      '미담당 학급',
      new_classroom_path
    )
    expect(response.body).to include(classroom_path(assigned_classroom), classroom_path(unassigned_classroom))
    expect(response.body).to include(school_path(school))
    expect(response.body).not_to include('다른 학교 학급')
    expect(response.body).to include(school_teachers_path(school))
    expect(response.body).not_to include('학교 운영 정보')
    expect(response.body).not_to include('선생님 목록')
    expect(response.body).to include(%(href="#{classrooms_path}"))
    expect(response.body).not_to include('id="classroom-school-filter"')
  end

  it 'keeps a regular teacher limited to assigned classrooms' do
    create(:school_membership, school: school, user: teacher)
    assigned = create(:classroom, school: school, name: '담당 학급')
    unassigned = create(:classroom, school: school, name: '미담당 학급')
    create(:classroom_membership, classroom: assigned, user: teacher, role: :teacher)
    sign_in teacher

    get classrooms_path

    expect(response.body).to include(assigned.name)
    expect(response.body).not_to include(unassigned.name)
    expect(response.body).not_to include(new_classroom_path)
    expect(response.body).not_to include('id="classroom-school-filter"')
  end

  it 'shows a school filter to an admin while keeping the full classroom list by default' do
    other_school = create(:school, name: '나래초등학교')
    classroom = create(:classroom, school: school, name: '새싹 학급')
    other_classroom = create(:classroom, school: other_school, name: '나래 학급')
    sign_in admin

    get classrooms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="classroom-school-filter"')
    expect(response.body).to include('name="school_id"')
    expect(response.body).to include('전체 학교')
    expect(response.body).to include(school.name, other_school.name)
    expect(response.body).to include(classroom.name, other_classroom.name)
    expect(response.body).to include(classroom_path(classroom), classroom_path(other_classroom))
    expect(response.body).not_to include(new_admin_school_path)
    expect(response.body).not_to include(edit_admin_school_path(school))
  end

  it 'filters classrooms by selected school for an admin' do
    other_school = create(:school, name: '나래초등학교')
    classroom = create(:classroom, school: school, name: '새싹 학급')
    other_classroom = create(:classroom, school: other_school, name: '나래 학급')
    teacher = create(:school_membership, school: school, user: create(:user, :teacher, name: '새싹 선생님')).user
    other_teacher = create(:school_membership, school: other_school, user: create(:user, :teacher, name: '나래 선생님')).user
    student = create(:user, :student, name: '새싹 학생')
    other_student = create(:user, :student, name: '나래 학생')
    create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
    create(:classroom_membership, classroom: other_classroom, user: other_teacher, role: :teacher)
    create(:classroom_membership, classroom: classroom, user: student, role: :student)
    create(:classroom_membership, classroom: other_classroom, user: other_student, role: :student)
    sign_in admin

    get classrooms_path, params: { school_id: school.id }

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(%r{<option selected="selected" value="#{school.id}">#{school.name}</option>})
    expect(response.body).to include(classroom.name, classroom_path(classroom), teacher.name, '학생 1명')
    expect(response.body).not_to include(other_classroom.name)
    expect(response.body).not_to include(classroom_path(other_classroom))
    expect(response.body).not_to include(other_teacher.name)
    expect(response.body).not_to include(other_student.name)
  end

  it 'treats an invalid admin classroom school filter as the full list' do
    classroom = create(:classroom, school: school, name: '새싹 학급')
    other_classroom = create(:classroom, school: create(:school), name: '다른 학급')
    sign_in admin

    get classrooms_path, params: { school_id: 'missing' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(classroom.name, other_classroom.name)
    expect(response.body).to include(classroom_path(classroom), classroom_path(other_classroom))
    expect(response.body).not_to include('selected="selected" value="missing"')
  end

  it 'allows a manager to show an unassigned classroom in their school' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    get classroom_path(classroom)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('교실 관리')
    expect(response.body).not_to include('오늘의 칭찬왕')
    expect(response.body).not_to include('학생 로그인')
    expect(response.body).not_to include(classroom_members_path(classroom))
  end

  it "rejects a manager showing another school's classroom" do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: create(:school))
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    get classroom_path(classroom)

    expect(response).to redirect_to(root_path)
  end

  it 'allows an admin to create a classroom with a school and grade' do
    sign_in admin

    post classrooms_path, params: {
      classroom: {
        name: '1학년 1반',
        school_id: school.id,
        grade: 1
      }
    }

    classroom = Classroom.find_by!(name: '1학년 1반')
    expect(response).to redirect_to(classroom_path(classroom))
    expect(classroom.school).to eq(school)
    expect(classroom.grade).to eq(1)
  end

  it 'rejects admin classroom creation without a school' do
    sign_in admin

    expect do
      post classrooms_path, params: {
        classroom: { name: '학교 없는 학급', school_id: '', grade: 1 }
      }
    end.not_to change(Classroom, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('학교')
    expect(response.body).to include('name="classroom[school_id]"')
  end

  it 'rejects admin classroom creation without a grade' do
    sign_in admin

    expect do
      post classrooms_path, params: {
        classroom: { name: '학년 없는 학급', school_id: school.id, grade: '' }
      }
    end.not_to change(Classroom, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('학년')
    expect(response.body).to include('name="classroom[grade]"')
  end

  it 'rejects admin classroom creation with an out-of-range grade' do
    sign_in admin

    expect do
      post classrooms_path, params: {
        classroom: { name: '잘못된 학년', school_id: school.id, grade: 7 }
      }
    end.not_to change(Classroom, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('학년')
  end

  it 'allows a manager to create a classroom fixed to their school' do
    manager = create(:user, :teacher)
    other_school = create(:school)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    post classrooms_path, params: {
      classroom: {
        name: '관리자 생성 학급',
        school_id: other_school.id,
        grade: 2,
        teacher_ids: [manager.id]
      }
    }

    classroom = Classroom.find_by!(name: '관리자 생성 학급')
    expect(response).to redirect_to(classroom_path(classroom))
    expect(classroom.school).to eq(school)
    expect(classroom.grade).to eq(2)
    expect(classroom.classroom_memberships.teacher.exists?(user: manager)).to eq(true)
  end

  it 'rejects manager classroom creation without a grade' do
    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    expect do
      post classrooms_path, params: {
        classroom: { name: '학년 없는 관리자 학급', grade: '', teacher_ids: [manager.id] }
      }
    end.not_to change(Classroom, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('학년')
  end

  it 'rejects manager classroom creation with an out-of-range grade' do
    manager = create(:user, :teacher)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    expect do
      post classrooms_path, params: {
        classroom: { name: '잘못된 관리자 학년', grade: 0, teacher_ids: [manager.id] }
      }
    end.not_to change(Classroom, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('학년')
  end

  it 'rejects classroom creation by a regular teacher' do
    sign_in teacher

    expect do
      post classrooms_path, params: {
        classroom: {
          name: '생성되면 안 되는 학급'
        }
      }
    end.not_to change(Classroom, :count)

    expect(response).to redirect_to(root_path)
  end

  it 'allows an admin to change an existing classroom school and grade' do
    classroom = create(:classroom, school: create(:school), grade: 2)
    create(:school_membership, school: school, user: teacher)
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    sign_in admin

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(school_id: school.id, grade: 6)
    }

    expect(response).to redirect_to(classroom_path(classroom))
    persisted_classroom = Classroom.find(classroom.id)
    expect(persisted_classroom.school_id).to eq(school.id)
    expect(persisted_classroom.grade).to eq(6)
    expect(classroom.reload.school_id).to eq(school.id)
    expect(classroom.grade).to eq(6)
    expect(classroom.classroom_memberships.teacher.exists?(user: teacher)).to eq(true)

    follow_redirect!
    expect(response.body).to include('교실 설정을 저장했습니다.')
  end

  it 'allows a manager to update basic classroom fields in their school' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school, name: '기존 학급', grade: 1)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(name: '변경 학급', grade: 5)
    }

    expect(response).to redirect_to(classroom_path(classroom))
    expect(classroom.reload).to have_attributes(name: '변경 학급', grade: 5, school: school)
  end

  it 'ignores operation setting params submitted by a manager' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school, name: '기존 학급', grade: 1, daily_compliment_king_enabled: true,
                                   weekly_compliment_king_enabled: false, monthly_compliment_king_enabled: false, message_policy: 'replies_only')
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(
        name: '변경 학급',
        grade: 4,
        daily_compliment_king_enabled: '0',
        weekly_compliment_king_enabled: '1',
        monthly_compliment_king_enabled: '1',
        message_policy: 'student_initiated'
      )
    }

    expect(response).to redirect_to(classroom_path(classroom))
    expect(classroom.reload).to have_attributes(
      name: '변경 학급',
      grade: 4,
      daily_compliment_king_enabled: true,
      weekly_compliment_king_enabled: false,
      monthly_compliment_king_enabled: false,
      message_policy: 'replies_only'
    )
  end

  it 'allows an assigned manager to update basic fields and operation settings' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school, name: '기존 학급', grade: 1, daily_compliment_king_enabled: true,
                                   weekly_compliment_king_enabled: false, monthly_compliment_king_enabled: false, message_policy: 'replies_only')
    create(:school_membership, :manager, school: school, user: manager)
    create(:classroom_membership, classroom: classroom, user: manager, role: :teacher)
    sign_in manager

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(
        name: '담당 관리자 학급',
        grade: 6,
        daily_compliment_king_enabled: '0',
        weekly_compliment_king_enabled: '1',
        monthly_compliment_king_enabled: '1',
        message_policy: 'student_initiated'
      )
    }

    expect(response).to redirect_to(classroom_path(classroom))
    expect(classroom.reload).to have_attributes(
      name: '담당 관리자 학급',
      grade: 6,
      daily_compliment_king_enabled: false,
      weekly_compliment_king_enabled: true,
      monthly_compliment_king_enabled: true,
      message_policy: 'student_initiated'
    )
  end

  it 'prevents a manager from deleting a classroom in their school' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    expect do
      delete classroom_path(classroom)
    end.not_to change(Classroom, :count)

    expect(response).to redirect_to(root_path)
  end

  it 'prevents a manager from moving a classroom to another school' do
    manager = create(:user, :teacher)
    other_school = create(:school)
    classroom = create(:classroom, school: school, name: '기존 학급', grade: 1)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(name: '변경되면 안 됨', school_id: other_school.id, grade: 6)
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('학교 관리자는 학급을 다른 학교로 이동할 수 없습니다.')
    expect(classroom.reload).to have_attributes(name: '기존 학급', grade: 1, school: school)
  end

  it 'rejects a blank grade submitted by a manager' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school, grade: 3)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(grade: '')
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(classroom.reload.grade).to eq(3)
    expect(response.body).to include('학년')
  end

  it 'rejects an out-of-range grade submitted by a manager' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school, grade: 3)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(grade: 7)
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(classroom.reload.grade).to eq(3)
    expect(response.body).to include('학년')
  end

  it 'rejects manager updates outside their school' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: create(:school), name: '다른 학교 학급')
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(name: '변경되면 안 됨')
    }

    expect(response).to redirect_to(root_path)
    expect(classroom.reload.name).to eq('다른 학교 학급')
  end

  it 'ignores school and grade params submitted by a teacher' do
    original_school = create(:school)
    other_school = create(:school)
    classroom = create(:classroom, school: original_school, grade: 3)
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    sign_in teacher

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(school_id: other_school.id, grade: 5)
    }

    expect(response).to redirect_to(classroom_path(classroom))
    expect(classroom.reload.school).to eq(original_school)
    expect(classroom.grade).to eq(3)
  end

  it 'keeps classroom identification while removing school and teacher management sections' do
    classroom = create(:classroom, name: '지정 교실', school: school, grade: 2)
    homeroom = create(:school_membership, school: school, user: create(:user, :teacher, name: '담당 선생님')).user
    create(:classroom_membership, classroom: classroom, user: homeroom, role: :teacher)
    sign_in admin

    get classrooms_path

    expect(response.body).to include('지정 교실', school.name, '2학년', '담당 선생님')
    expect(response.body).to include(classroom_path(classroom), edit_classroom_path(classroom))
    expect(response.body).not_to include(new_admin_teacher_path)
    expect(response.body).not_to include(edit_admin_teacher_path(homeroom))
    expect(response.body).not_to include(new_admin_school_path)
    expect(response.body).not_to include(edit_admin_school_path(school))
    expect(response.body).not_to include('선생님 목록')
    expect(response.body).not_to include('학교 운영 정보')
  end

  it 'rejects a grade outside the elementary school range' do
    classroom = create(:classroom, school: school, grade: 3)
    sign_in admin

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(grade: 7)
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(classroom.reload.grade).to eq(3)
    expect(response.body).to include('학년')
  end

  it 'rejects removing the grade from an existing classroom' do
    classroom = create(:classroom, school: school, grade: 3)
    sign_in admin

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(grade: '')
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(classroom.reload.grade).to eq(3)
    expect(response.body).to include('학년')
  end

  it 'safely rejects a school id that does not exist' do
    classroom = create(:classroom, school: school, grade: 3)
    sign_in admin

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(school_id: School.maximum(:id).to_i + 10_000)
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(classroom.reload.school).to eq(school)
    expect(response.body).to include('학교')
  end

  it 'rejects removing the school from an existing classroom' do
    classroom = create(:classroom, school: school, grade: 3)
    sign_in admin

    patch classroom_path(classroom), params: {
      classroom: classroom_update_params(classroom).merge(school_id: '')
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(classroom.reload.school).to eq(school)
    expect(response.body).to include('학교')
  end

  def classroom_update_params(classroom)
    {
      name: classroom.name,
      daily_compliment_king_enabled: classroom.daily_compliment_king_enabled ? '1' : '0',
      weekly_compliment_king_enabled: classroom.weekly_compliment_king_enabled ? '1' : '0',
      monthly_compliment_king_enabled: classroom.monthly_compliment_king_enabled ? '1' : '0',
      message_policy: classroom.message_policy
    }
  end
end
