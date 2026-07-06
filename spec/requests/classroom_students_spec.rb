require "rails_helper"

RSpec.describe "Classroom students", type: :request do
  include ActionView::RecordIdentifier

  let(:teacher) { create(:user, :teacher) }
  let(:classroom) { create(:classroom) }
  let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }

  before do
    create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher")
    sign_in teacher
  end

  describe "POST /classrooms/:classroom_id/students" do
    it "assigns a gendered avatar_key without reusing available keys in the classroom" do
      User::BOY_AVATAR_KEYS.first(22).each do |avatar_key|
        student = create(:user, :student, gender: "boy", avatar_key: avatar_key)
        create(:classroom_membership, user: student, classroom: classroom, role: "student")
      end

      post classroom_students_path(classroom), params: {
        user: {
          name: "새 학생",
          email: "new-student@example.com",
          password: "password123",
          gender: "boy"
        }
      }

      student = User.find_by!(email: "new-student@example.com")
      expect(student.gender).to eq("boy")
      expect(student.avatar_key).to eq("boy23")
      expect(response).to redirect_to(classroom_path(classroom))
    end

    it "creates a student and classroom membership with turbo stream" do
      expect {
        post classroom_students_path(classroom),
          params: {
            user: {
              name: "터보 학생",
              email: "turbo-student@example.com",
              password: "password123",
              gender: "girl"
            }
          },
          headers: turbo_headers
      }.to change(User.student, :count).by(1)
        .and change(ClassroomMembership, :count).by(1)

      student = User.find_by!(email: "turbo-student@example.com")
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(classroom.classroom_memberships.exists?(user: student, role: "student")).to eq(true)
    end

    it "returns 422 with turbo stream when the student is invalid" do
      expect {
        post classroom_students_path(classroom),
          params: {
            user: {
              name: "",
              email: "invalid-student@example.com",
              password: "password123",
              gender: "boy"
            }
          },
          headers: turbo_headers
      }.not_to change(User.student, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "rejects a teacher outside the classroom" do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      expect {
        post classroom_students_path(classroom), params: {
          user: {
            name: "외부 생성",
            email: "outside-create@example.com",
            password: "password123",
            gender: "boy"
          }
        }
      }.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end

    it "rejects a student" do
      student = create(:user, :student)
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      sign_out teacher
      sign_in student

      expect {
        post classroom_students_path(classroom), params: {
          user: {
            name: "학생 생성",
            email: "student-create@example.com",
            password: "password123",
            gender: "girl"
          }
        }
      }.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /classrooms/:classroom_id/students/bulk_create" do
    it "creates students from boy_count and girl_count" do
      post bulk_create_classroom_students_path(classroom), params: {
        boy_count: 2,
        girl_count: 1
      }

      students = classroom.students.order(:created_at).last(3)
      expect(students.map(&:gender)).to contain_exactly("boy", "boy", "girl")
      expect(students.map(&:avatar_key)).to all(be_present)
      expect(response).to redirect_to(classroom_path(classroom))
    end

    it "returns a turbo stream alert without creating students when the requested count exceeds 30" do
      expect {
        post bulk_create_classroom_students_path(classroom),
          params: {
            boy_count: 30,
            girl_count: 30
          },
          headers: turbo_headers
      }.not_to change(User.student, :count)

      expect(response).not_to be_redirect
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="modal"')
      expect(response.body).to include("한 번에 자동 생성할 수 있는 학생은 최대 30명입니다.")
    end

    it "creates students and updates the students list and modal with turbo stream" do
      expect {
        post bulk_create_classroom_students_path(classroom),
          params: {
            boy_count: 1,
            girl_count: 1
          },
          headers: turbo_headers
      }.to change(User.student, :count).by(2)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(target="students_list_#{classroom.id}"))
      expect(response.body).to include('target="modal"')
    end

    it "rejects a teacher outside the classroom" do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      expect {
        post bulk_create_classroom_students_path(classroom), params: {
          boy_count: 1,
          girl_count: 1
        }
      }.not_to change(User.student, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /classrooms/:classroom_id/students/:id" do
    let(:student) { create(:user, :student) }
    let!(:student_membership) do
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
    end

    it "shows the shared student profile card, navigation, and teacher operations" do
      create(:coupon_template, created_by: teacher, active: true)

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.xpath("//*[normalize-space(text())='학생 정보']")).to be_empty
      expect(response.body).to include(student.name)
      expect(response.body).to include(classroom.name)
      expect(response.body).to include("쿠폰 관리")
      expect(response.body).to include("한눈에 보기")
      expect(response.body).to include("학생 정보·PIN 수정")
      expect(response.body).to include("칭찬하기")
      expect(response.body).to include("교실로 돌아가기")
      expect(response.body).to include("쿠폰 지급")
      profile_card = document.at_css("[data-student-profile-card]")
      expect(profile_card.text).to include("쿠폰 지급")
      assignment_link = profile_card.at_css(
        %(a[href="#{coupon_assignment_classroom_student_path(classroom, student)}"])
      )
      expect(assignment_link["data-turbo-frame"]).to eq(dom_id(student, :coupon_assignment))
      expect(response.body).not_to include("활성 쿠폰 중 하나를 가중치에 따라 랜덤으로 지급합니다.")
      expect(response.body).not_to include("선택한 쿠폰 지급")
      expect(response.body).to include(classroom_student_messages_path(classroom, student))
      expect(response.body).to include(dashboard_classroom_student_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
      coupon_navigation = document.at_css(%(a[href="#{classroom_student_path(classroom, student)}"]))
      expect(coupon_navigation["class"]).to include("border-blue-500")
      expect(response.body).not_to include("user_message[body]")
      expect(response.body).not_to include("최근 발급 쿠폰")
      expect(response.body).not_to include("칭찬 타임라인")
    end

    it "shows pending coupon use requests as work to process" do
      template = create(:coupon_template, created_by: teacher)
      coupon = create(
        :user_coupon,
        user: student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher
      )
      create(
        :coupon_use_request,
        user_coupon: coupon,
        classroom: classroom,
        student: student,
        requested_by: student
      )

      get classroom_student_path(classroom, student)

      expect(response.body).to include("처리할 일")
      expect(response.body).to include("쿠폰 사용 요청 1건")
      expect(response.body).to include("사용 승인")
    end

    it "hides message operations and the message section when messages are disabled" do
      classroom.update!(message_policy: "disabled")

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(classroom_student_messages_path(classroom, student))
      expect(response.body).not_to include(dom_id(student, :message_section))
      expect(response.body).not_to include("user_message[body]")
    end

    it "shows the same management operations to an admin" do
      admin = create(:user, :admin)
      sign_out teacher
      sign_in admin

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("학생 정보·PIN 수정")
      expect(response.body).to include("칭찬하기")
      expect(response.body).to include("교실로 돌아가기")
      expect(response.body).to include("쿠폰 지급")
      expect(response.body).to include(classroom_student_messages_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
    end

    it "does not expose teacher management operations to the student" do
      sign_out teacher
      sign_in student

      get classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("학생 정보·PIN 수정")
      expect(response.body).not_to include("칭찬하기")
      expect(response.body).not_to include("쿠폰 지급")
      expect(response.body).not_to include("선택한 쿠폰 지급")
      expect(response.body).not_to include("교실로 돌아가기")
      expect(response.body).to include("한눈에 보기")
      expect(response.body).to include(classroom_student_messages_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
    end

    it "renders the coupon assignment card in its turbo frame" do
      create(:coupon_template, created_by: teacher, active: true)

      get coupon_assignment_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(dom_id(student, :coupon_assignment))
      expect(response.body).to include("활성 쿠폰 중 하나를 가중치에 따라 랜덤으로 지급합니다.")
      expect(response.body).to include("쿠폰 뽑기")
      expect(response.body).to include("선택한 쿠폰 지급")
      expect(response.body).to match(/value="쿠폰 지급"/)
    end

    it "shows an empty assignment state when the teacher has no active templates" do
      get coupon_assignment_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("쿠폰 지급")
      expect(response.body).to include("지급 가능한 활성 쿠폰 템플릿이 없습니다.")
      expect(response.body).not_to include(classroom_student_coupons_path(classroom, student))
    end

    it "rejects the student from loading the coupon assignment card" do
      sign_out teacher
      sign_in student

      get coupon_assignment_classroom_student_path(classroom, student)

      expect(response).to redirect_to(root_path)
    end

    it "shows coupon and compliment history on the activity page" do
      template = create(:coupon_template, created_by: teacher, title: "기록 쿠폰")
      create(
        :user_coupon,
        user: student,
        classroom: classroom,
        coupon_template: template,
        issued_by: teacher
      )
      create(:compliment, classroom: classroom, giver: teacher, receiver: student)

      get activity_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(response.body).to include(student.name)
      expect(response.body).to include("한눈에 보기")
      expect(response.body).to include(dashboard_classroom_student_path(classroom, student))
      expect(response.body).to include(activity_classroom_student_path(classroom, student))
      activity_navigation = document.at_css(%(a[href="#{activity_classroom_student_path(classroom, student)}"]))
      expect(activity_navigation["class"]).to include("border-blue-500")
      expect(response.body).to include("최근 발급 쿠폰")
      expect(response.body).to include("기록 쿠폰")
      expect(response.body).to include("칭찬 타임라인")
      expect(response.body).to include(dom_id(student, :recent_issued_coupons))
      expect(response.body).to include(dom_id(student, :compliments))
      expect(response.body).not_to include("쿠폰 지급")
      expect(response.body).not_to include("쿠폰 뽑기")
      expect(response.body).not_to include("선택한 쿠폰 지급")
    end

    it "allows the student to view their own activity page" do
      sign_out teacher
      sign_in student

      get activity_classroom_student_path(classroom, student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("활동 기록")
      expect(response.body).to include("최근 발급 쿠폰")
      expect(response.body).to include("칭찬 타임라인")
    end

    it "rejects a teacher outside the classroom from the activity page" do
      outsider = create(:user, :teacher)
      sign_out teacher
      sign_in outsider

      get activity_classroom_student_path(classroom, student)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /classrooms/:classroom_id/students/:id" do
    it "reassigns avatar_key when gender changes and no custom avatar is attached" do
      student = create(:user, :student, gender: "boy", avatar_key: "boy01")
      create(:classroom_membership, user: student, classroom: classroom, role: "student")
      User::GIRL_AVATAR_KEYS.first(16).each do |avatar_key|
        classmate = create(:user, :student, gender: "girl", avatar_key: avatar_key)
        create(:classroom_membership, user: classmate, classroom: classroom, role: "student")
      end

      patch classroom_student_path(classroom, student), params: {
        user: {
          name: student.name,
          email: student.email,
          gender: "girl"
        }
      }

      expect(student.reload.gender).to eq("girl")
      expect(student.avatar_key).to eq("girl17")
      expect(response).to redirect_to(edit_classroom_student_path(classroom, student))
    end
  end

  describe "DELETE /classrooms/:classroom_id/students/:id" do
    it "hard deletes a student without activity or another classroom membership" do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: "student")

      expect {
        delete classroom_student_path(classroom, student)
      }.to change(User, :count).by(-1)
        .and change(ClassroomMembership, :count).by(-1)

      expect(User.exists?(student.id)).to eq(false)
      expect(ClassroomMembership.exists?(membership.id)).to eq(false)
      expect(response).to redirect_to(classroom_path(classroom))
      expect(flash[:notice]).to eq(I18n.t("students.destroy.hard_deleted"))
    end

    it "inactivates the membership when the student has activity in the classroom" do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:compliment, classroom: classroom, giver: teacher, receiver: student)

      expect {
        delete classroom_student_path(classroom, student)
      }.not_to change(User, :count)

      expect(membership.reload).to be_inactive
      expect(flash[:notice]).to eq(I18n.t("students.destroy.inactivated"))
    end

    it "inactivates the membership when the student has a coupon in the classroom" do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:user_coupon, user: student, classroom: classroom)

      expect {
        delete classroom_student_path(classroom, student)
      }.not_to change(User, :count)

      expect(membership.reload).to be_inactive
    end

    it "inactivates the membership when the student has a coupon use request in the classroom" do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: "student")
      coupon = create(:user_coupon, user: student, classroom: classroom)
      create(:coupon_use_request, user_coupon: coupon, classroom: classroom, student: student, requested_by: student)

      expect {
        delete classroom_student_path(classroom, student)
      }.not_to change(User, :count)

      expect(membership.reload).to be_inactive
    end

    it "inactivates the membership when the student has a message in the classroom" do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:user_message, classroom: classroom, sender: teacher, recipient: student)

      expect {
        delete classroom_student_path(classroom, student)
      }.not_to change(User, :count)

      expect(membership.reload).to be_inactive
    end

    it "inactivates the current membership when the student has current classroom activity and another membership" do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: "student")
      other_membership = create(:classroom_membership, user: student, classroom: create(:classroom), role: "student")
      create(:compliment, classroom: classroom, giver: teacher, receiver: student)

      expect {
        delete classroom_student_path(classroom, student)
      }.not_to change(User, :count)

      expect(membership.reload).to be_inactive
      expect(other_membership.reload).to be_active
    end

    it "removes only the current membership when the student belongs to another classroom" do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: "student")
      other_membership = create(:classroom_membership, user: student, classroom: create(:classroom), role: "student")

      expect {
        delete classroom_student_path(classroom, student)
      }.not_to change(User, :count)

      expect(ClassroomMembership.exists?(membership.id)).to eq(false)
      expect(ClassroomMembership.exists?(other_membership.id)).to eq(true)
      expect(flash[:notice]).to eq(I18n.t("students.destroy.removed_from_classroom"))
    end

    it "inactivates the membership when only global student activity exists" do
      student = create(:user, :student)
      membership = create(:classroom_membership, user: student, classroom: classroom, role: "student")
      create(:compliment, classroom: create(:classroom), giver: teacher, receiver: student)

      expect {
        delete classroom_student_path(classroom, student)
      }.not_to change(User, :count)

      expect(membership.reload).to be_inactive
      expect(flash[:notice]).to eq(I18n.t("students.destroy.inactivated"))
    end
  end
end
