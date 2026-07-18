require "rails_helper"

RSpec.describe "UserCoupons#index", type: :request do
  describe "GET /users/:user_id/coupons" do
    let(:first_classroom) { create(:classroom) }
    let(:second_classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student) }
    let(:other_student) { create(:user, :student) }
    let(:first_template) { create(:coupon_template, title: "담당 학급 쿠폰") }
    let(:second_template) { create(:coupon_template, title: "미담당 학급 쿠폰") }
    let(:other_template) { create(:coupon_template, title: "다른 학생 쿠폰") }

    before do
      create(:classroom_membership, user: teacher, classroom: first_classroom, role: "teacher")
      create(:classroom_membership, user: student, classroom: first_classroom, role: "student", status: "active")
      create(:classroom_membership, user: student, classroom: second_classroom, role: "student", status: "inactive")
      create(:classroom_membership, user: other_student, classroom: first_classroom, role: "student", status: "active")
      create(:user_coupon, user: student, classroom: first_classroom, coupon_template: first_template)
      create(:user_coupon, user: student, classroom: second_classroom, coupon_template: second_template)
      create(:user_coupon, user: other_student, classroom: first_classroom, coupon_template: other_template)
    end

    it "shows only the target student's coupons from the teacher's assigned classrooms" do
      sign_in teacher

      get user_coupons_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(first_template.title)
      expect(response.body).not_to include(second_template.title)
      expect(response.body).not_to include(other_template.title)
    end

    it "shows all of the target student's coupons to an admin" do
      sign_in create(:user, :admin)

      get user_coupons_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(first_template.title, second_template.title)
      expect(response.body).not_to include(other_template.title)
    end
  end
end
