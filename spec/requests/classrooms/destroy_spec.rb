require 'rails_helper'

RSpec.describe 'Classroom deletion', type: :request do
  let(:school) { create(:school) }

  it 'lets an admin delete an unused classroom while preserving the teacher user' do
    admin = create(:user, :admin)
    teacher = create(:user, :teacher)
    classroom = create(:classroom, school: school)
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    sign_in admin

    expect do
      delete classroom_path(classroom)
    end.to change(Classroom, :count).by(-1)

    expect(response).to redirect_to(classrooms_path)
    expect(response).to have_http_status(:see_other)
    expect(User.exists?(teacher.id)).to eq(true)
    expect(flash[:notice]).to eq(I18n.t('classrooms.destroy.success'))
  end

  it 'rejects direct deletion by an assigned teacher' do
    teacher = create(:user, :teacher)
    classroom = create(:classroom, school: school)
    membership = create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    sign_in teacher

    expect do
      delete classroom_path(classroom)
    end.not_to change(Classroom, :count)

    expect(response).to redirect_to(root_path)
    expect(response).to have_http_status(:found)
    expect(ClassroomMembership.exists?(membership.id)).to eq(true)
    expect(flash[:notice]).to be_nil
  end

  it 'rejects direct deletion by an unassigned school manager' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school)
    create(:school_membership, :manager, school: school, user: manager)
    sign_in manager

    expect do
      delete classroom_path(classroom)
    end.not_to change(Classroom, :count)

    expect(response).to redirect_to(root_path)
    expect(response).to have_http_status(:found)
    expect(flash[:notice]).to be_nil
  end

  it 'rejects direct deletion by a manager who is also an assigned teacher' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school)
    create(:school_membership, :manager, school: school, user: manager)
    membership = create(:classroom_membership, classroom: classroom, user: manager, role: 'teacher')
    sign_in manager

    expect do
      delete classroom_path(classroom)
    end.not_to change(Classroom, :count)

    expect(response).to redirect_to(root_path)
    expect(response).to have_http_status(:found)
    expect(ClassroomMembership.exists?(membership.id)).to eq(true)
  end

  it 'preserves an admin classroom when a student membership exists' do
    admin = create(:user, :admin)
    classroom = create(:classroom, school: school)
    membership = create(:classroom_membership, classroom: classroom, role: 'student', status: 'inactive')
    sign_in admin

    expect do
      delete classroom_path(classroom)
    end.not_to change(Classroom, :count)

    expect(response).to redirect_to(edit_classroom_path(classroom))
    expect(response).to have_http_status(:see_other)
    expect(ClassroomMembership.exists?(membership.id)).to eq(true)
    expect(flash[:alert]).to include(I18n.t('activerecord.errors.models.classroom.attributes.base.students_or_history_present'))
    expect(flash[:notice]).to be_nil
  end

  it 'preserves an admin classroom and its activity records' do
    admin = create(:user, :admin)
    classroom = create(:classroom, school: school)
    compliment = create(:compliment, classroom: classroom)
    sign_in admin

    expect do
      delete classroom_path(classroom)
    end.not_to change(Classroom, :count)

    expect(response).to redirect_to(edit_classroom_path(classroom))
    expect(response).to have_http_status(:see_other)
    expect(Compliment.exists?(compliment.id)).to eq(true)
    expect(flash[:alert]).to include(I18n.t('activerecord.errors.models.classroom.attributes.base.students_or_history_present'))
    expect(flash[:notice]).to be_nil
  end

  it 'shows the delete area only on an admin edit page' do
    admin = create(:user, :admin)
    teacher = create(:user, :teacher)
    classroom = create(:classroom, school: school)
    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    delete_description = I18n.t('classrooms.edit.delete_description')

    sign_in admin
    get edit_classroom_path(classroom)

    admin_document = Nokogiri::HTML(response.body)
    admin_delete_links = admin_document.css(
      %(a[href="#{classroom_path(classroom)}"][data-turbo-method="delete"])
    )

    expect(response.body).to include(delete_description)
    expect(admin_delete_links).not_to be_empty

    sign_in teacher
    get edit_classroom_path(classroom)

    teacher_document = Nokogiri::HTML(response.body)
    teacher_delete_links = teacher_document.css(
      %(a[href="#{classroom_path(classroom)}"][data-turbo-method="delete"])
    )

    expect(response.body).not_to include(delete_description)
    expect(teacher_delete_links).to be_empty
  end

  it 'hides the delete area from school managers, including assigned managers' do
    manager = create(:user, :teacher)
    classroom = create(:classroom, school: school)
    create(:school_membership, :manager, school: school, user: manager)
    create(:classroom_membership, classroom: classroom, user: manager, role: 'teacher')
    sign_in manager

    get edit_classroom_path(classroom)

    document = Nokogiri::HTML(response.body)
    classroom_delete_links = document.css(
      %(a[href="#{classroom_path(classroom)}"][data-turbo-method="delete"])
    )

    expect(response.body).not_to include(I18n.t('classrooms.edit.delete_description'))
    expect(classroom_delete_links).to be_empty
  end
end
