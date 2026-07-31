require 'rails_helper'

RSpec.describe 'Navigation', type: :request do
  def navbar
    document = Nokogiri::HTML(response.body)
    document.at_css('[data-navigation-root="navbar"]').tap do |navigation|
      expect(navigation).to be_present
    end
  end

  def navbar_links
    navbar.css('a[href]').map { |link| link['href'] }
  end

  it 'shows the sign in link to a guest' do
    get new_user_session_path

    expect(navbar.text).to include('Sign in')
    expect(navbar_links).to include(new_user_session_path)
  end

  it 'shows student navigation without teacher account or management links' do
    classroom = create(:classroom)
    student = create(:user, :student)
    create(:classroom_membership, classroom: classroom, user: student, role: :student)
    sign_in student

    get classroom_student_path(classroom, student)

    expect(navbar_links).to include(
      dashboard_path,
      user_path(student),
      destroy_student_session_path
    )
    expect(navbar.text).to include(I18n.t('navigation.my_praise_book'))
    expect(navbar_links).not_to include(
      edit_user_registration_path,
      destroy_user_session_path,
      coupon_templates_path,
      compliment_templates_path
    )
  end

  it 'links a teacher without classrooms to the classroom index' do
    teacher = create(:user, :teacher)
    sign_in teacher

    get classrooms_path

    expect(navbar_links).to include(classrooms_path)
  end

  it 'links a teacher with one classroom directly to that classroom' do
    teacher = create(:user, :teacher)
    classroom = create(:classroom)
    create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
    sign_in teacher

    get classrooms_path

    expect(navbar_links).to include(classroom_path(classroom))
  end

  it 'shows every assigned classroom to a teacher with multiple classrooms' do
    school = create(:school)
    teacher = create(:user, :teacher)
    classrooms = create_list(:classroom, 2, school: school)
    classrooms.each do |classroom|
      create(:classroom_membership, classroom: classroom, user: teacher, role: :teacher)
    end
    sign_in teacher

    get classrooms_path

    classrooms.each do |classroom|
      expect(navbar_links).to include(classroom_path(classroom))
    end
  end
end
