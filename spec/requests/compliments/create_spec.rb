require "rails_helper"

RSpec.describe "Compliments#create", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "POST /classrooms/:classroom_id/compliments" do
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student, points: 0) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: "teacher") }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: "student") }

    def json_body
      JSON.parse(response.body)
    end

    it "rejects a guest user before authorization" do
      expect {
        post classroom_compliments_path(classroom),
          params: { compliment: { receiver_id: student.id } },
          as: :json
      }.not_to change(Compliment, :count)

      expect(response).to have_http_status(:unauthorized)
      expect(student.reload.points).to eq(0)
    end

    it "allows the classroom teacher to create a compliment" do
      sign_in teacher

      post classroom_compliments_path(classroom),
        params: { compliment: { receiver_id: student.id } },
        as: :json

      expect(response).to have_http_status(:created)
      expect(json_body).to eq("ok" => true, "receiver_id" => student.id)
    end

    it "allows an admin to create a compliment" do
      admin = create(:user, :admin)
      sign_in admin

      expect {
        post classroom_compliments_path(classroom),
          params: { compliment: { receiver_id: student.id } },
          as: :json
      }.to change(Compliment, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(Compliment.last.giver).to eq(admin)
    end

    it "rejects a student" do
      sign_in student

      expect {
        post classroom_compliments_path(classroom),
          params: { compliment: { receiver_id: student.id } },
          as: :json
      }.not_to change(Compliment, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq("ok" => false, "error" => "not_authorized")
      expect(student.reload.points).to eq(0)
    end

    it "rejects a teacher outside the classroom" do
      outsider = create(:user, :teacher)
      sign_in outsider

      expect {
        post classroom_compliments_path(classroom),
          params: { compliment: { receiver_id: student.id } },
          as: :json
      }.not_to change(Compliment, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq("ok" => false, "error" => "not_authorized")
      expect(student.reload.points).to eq(0)
    end

    it "rejects a receiver who does not belong to the classroom" do
      other_student = create(:user, :student, points: 0)
      sign_in teacher

      expect {
        post classroom_compliments_path(classroom),
          params: { compliment: { receiver_id: other_student.id } },
          as: :json
      }.not_to change(Compliment, :count)

      expect(response).to have_http_status(:not_found)
      expect(other_student.reload.points).to eq(0)
    end

    it "increments the receiver points by one on success" do
      sign_in teacher

      expect {
        post classroom_compliments_path(classroom),
          params: { compliment: { receiver_id: student.id } },
          as: :json
      }.to change(Compliment, :count).by(1)
        .and change { student.reload.points }.by(1)

      compliment = Compliment.last

      expect(compliment.classroom).to eq(classroom)
      expect(compliment.giver).to eq(teacher)
      expect(compliment.receiver).to eq(student)
    end

    it "returns 409 for a duplicate request inside the duplicate window" do
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        post classroom_compliments_path(classroom),
          params: { compliment: { receiver_id: student.id } },
          as: :json

        expect(response).to have_http_status(:created)

        expect {
          post classroom_compliments_path(classroom),
            params: { compliment: { receiver_id: student.id } },
            as: :json
        }.not_to change(Compliment, :count)

        expect(response).to have_http_status(:conflict)
        expect(json_body).to eq("ok" => false, "error" => "duplicate_request")
        expect(student.reload.points).to eq(1)
      end
    end

    it "rolls back both compliment creation and points increment when the transaction fails" do
      sign_in teacher

      allow_any_instance_of(User).to receive(:increment!).and_raise(
        ActiveRecord::RecordInvalid.new(student)
      )

      expect {
        post classroom_compliments_path(classroom),
          params: { compliment: { receiver_id: student.id } },
          as: :json
      }.not_to change(Compliment, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["ok"]).to eq(false)
      expect(student.reload.points).to eq(0)
    end
  end
end
