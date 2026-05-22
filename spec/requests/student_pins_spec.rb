require "rails_helper"

RSpec.describe "Student PIN management", type: :request do
  let(:student) { create(:user, :student, student_pin: "1234") }
  let(:teacher) { create(:user, :teacher) }
  let(:admin) { create(:user, :admin) }

  it "allows a signed-in student to open the PIN edit page" do
    sign_in student

    get edit_student_pin_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("PIN 변경")
    expect(response.body).to include('name="current_pin"')
  end

  it "lets a student change their own PIN with the current PIN" do
    sign_in student

    patch student_pin_path, params: {
      current_pin: "1234",
      student_pin: "4321",
      student_pin_confirmation: "4321"
    }

    expect(response).to redirect_to(user_path(student))
    student.reload
    expect(student.authenticate_student_pin("1234")).to be_falsey
    expect(student.authenticate_student_pin("4321")).to be_truthy
  end

  it "rejects an incorrect current PIN" do
    original_digest = student.student_pin_digest
    sign_in student

    patch student_pin_path, params: {
      current_pin: "0000",
      student_pin: "4321",
      student_pin_confirmation: "4321"
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("현재 PIN을 확인해 주세요.")
    expect(response.body).not_to include("4321")
    expect(student.reload.student_pin_digest).to eq(original_digest)
  end

  it "rejects mismatched PIN confirmation" do
    original_digest = student.student_pin_digest
    sign_in student

    patch student_pin_path, params: {
      current_pin: "1234",
      student_pin: "4321",
      student_pin_confirmation: "1111"
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("새 PIN 확인이 일치하지 않습니다.")
    expect(response.body).not_to include("4321")
    expect(response.body).not_to include("1111")
    expect(student.reload.student_pin_digest).to eq(original_digest)
  end

  it "rejects a new PIN that is not four digits" do
    original_digest = student.student_pin_digest
    sign_in student

    patch student_pin_path, params: {
      current_pin: "1234",
      student_pin: "12ab",
      student_pin_confirmation: "12ab"
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("새 PIN은 4자리 숫자여야 합니다.")
    expect(response.body).not_to include("12ab")
    expect(student.reload.student_pin_digest).to eq(original_digest)
  end

  it "does not show the PIN change link on non-student pages" do
    sign_in teacher

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("PIN 변경")
  end

  it "redirects a teacher away from the PIN edit page" do
    sign_in teacher

    get edit_student_pin_path

    expect(response).to redirect_to(root_path)
  end

  it "redirects an admin away from the PIN edit page" do
    sign_in admin

    get edit_student_pin_path

    expect(response).to redirect_to(root_path)
  end

  it "requires sign in" do
    get edit_student_pin_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
