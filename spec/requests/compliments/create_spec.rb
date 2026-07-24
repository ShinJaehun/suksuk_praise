require 'rails_helper'

RSpec.describe 'Compliments#create', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe 'POST /classrooms/:classroom_id/compliments' do
    let(:classroom) { create(:classroom) }
    let(:teacher) { create(:user, :teacher) }
    let(:student) { create(:user, :student, points: 0) }
    let!(:teacher_membership) { create(:classroom_membership, user: teacher, classroom: classroom, role: 'teacher') }
    let!(:student_membership) { create(:classroom_membership, user: student, classroom: classroom, role: 'student') }

    def json_body
      JSON.parse(response.body)
    end

    it 'rejects a guest user before authorization' do
      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:unauthorized)
      expect(student.reload.points).to eq(0)
    end

    it 'allows the classroom teacher to create a compliment' do
      sign_in teacher

      post classroom_compliments_path(classroom),
           params: { compliment: { receiver_id: student.id } },
           as: :json

      expect(response).to have_http_status(:created)
      expect(json_body).to eq('ok' => true, 'receiver_id' => student.id)
    end

    it 'redirects to the classroom student page on HTML success' do
      sign_in teacher

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } }
      end.to change(Compliment, :count).by(1)
                                       .and change { student.reload.points }.by(1)

      expect(response).to redirect_to(classroom_student_path(classroom, student))
      expect(response).to have_http_status(:see_other)
    end

    it 'allows an admin to create a compliment' do
      admin = create(:user, :admin)
      sign_in admin

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end.to change(Compliment, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(Compliment.last.giver).to eq(admin)
    end

    it 'rejects a student' do
      sign_in student

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq('ok' => false, 'error' => 'not_authorized')
      expect(student.reload.points).to eq(0)
    end

    it 'rejects a teacher outside the classroom' do
      outsider = create(:user, :teacher)
      sign_in outsider

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq('ok' => false, 'error' => 'not_authorized')
      expect(student.reload.points).to eq(0)
    end

    it 'rejects an unassigned school manager' do
      manager = create(:user, :teacher)
      create(:school_membership, :manager, school: classroom.school, user: manager)
      sign_in manager

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq('ok' => false, 'error' => 'not_authorized')
      expect(student.reload.points).to eq(0)
    end

    it 'rejects a receiver who does not belong to the classroom' do
      other_student = create(:user, :student, points: 0)
      sign_in teacher

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: other_student.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:not_found)
      expect(other_student.reload.points).to eq(0)
    end

    it 'rejects an inactive receiver' do
      student_membership.inactive!
      sign_in teacher

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:not_found)
      expect(student.reload.points).to eq(0)
    end

    it 'increments the receiver points by one on success' do
      sign_in teacher

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end.to change(Compliment, :count).by(1)
                                       .and change { student.reload.points }.by(1)

      compliment = Compliment.last

      expect(compliment.classroom).to eq(classroom)
      expect(compliment.giver).to eq(teacher)
      expect(compliment.receiver).to eq(student)
      expect(compliment.compliment_preset).to be_nil
      expect(compliment.reason).to be_nil
    end

    it 'creates a custom compliment with a preset snapshot and increments points' do
      preset = create(:compliment_preset, user: teacher, title: '다른 친구를 위해 봉사함')
      sign_in teacher

      expect do
        post classroom_compliments_path(classroom),
             params: {
               compliment: {
                 receiver_id: student.id,
                 compliment_preset_id: preset.id,
                 reason: '클라이언트 조작 문구'
               }
             },
             as: :json
      end.to change(Compliment, :count).by(1)
                                       .and change { student.reload.points }.by(1)

      compliment = Compliment.last
      expect(compliment.compliment_preset).to eq(preset)
      expect(compliment.reason).to eq('다른 친구를 위해 봉사함')
    end

    it 'counts custom compliments in the existing total compliment count' do
      preset = create(:compliment_preset, user: teacher, title: '교실 정리에 참여함')
      sign_in teacher

      post classroom_compliments_path(classroom),
           params: { compliment: { receiver_id: student.id, compliment_preset_id: preset.id } },
           as: :json

      expect(Compliment.where(classroom: classroom, receiver: student).count).to eq(1)
    end

    it "rejects another user's preset without changing compliments or points" do
      other_teacher = create(:user, :teacher)
      create(:classroom_membership, classroom: classroom, user: other_teacher, role: 'teacher')
      other_preset = create(:compliment_preset, user: other_teacher, title: '다른 교사 문구')
      sign_in teacher

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id, compliment_preset_id: other_preset.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:not_found)
      expect(student.reload.points).to eq(0)
    end

    it 'rejects an inactive preset without changing compliments or points' do
      preset = create(:compliment_preset, user: teacher, title: '비활성 문구', active: false)
      sign_in teacher

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id, compliment_preset_id: preset.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:not_found)
      expect(student.reload.points).to eq(0)
    end

    it 'rejects a missing preset without falling back to a general compliment' do
      sign_in teacher

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id, compliment_preset_id: '999999' } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:not_found)
      expect(student.reload.points).to eq(0)
    end

    it 'returns a turbo stream response on success' do
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: 1.day.ago)

        expect do
          post classroom_compliments_path(classroom),
               params: { compliment: { receiver_id: student.id } },
               headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }
        end.to change(Compliment, :count).by(1)
                                         .and change { student.reload.points }.by(1)
      end

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('오늘 칭찬')
      expect(response.body).not_to include('칭찬(포인트)')
      expect(response.body).to match(%r{오늘 칭찬.*text-2xl[^>]*>1</div>}m)
    end

    it 'keeps general and custom compliment controls after turbo stream refresh' do
      preset = create(:compliment_preset, user: teacher, title: '친구의 학습을 도와줌')
      sign_in teacher

      post classroom_compliments_path(classroom),
           params: { compliment: { receiver_id: student.id, compliment_preset_id: preset.id } },
           headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('ui.buttons.compliment'))
      expect(response.body).to include(I18n.t('ui.buttons.custom_compliment'))
    end

    it 'shows the custom compliment button only when the current user has active presets' do
      custom_compliment_path = new_classroom_compliment_path(classroom)
      sign_in teacher

      get classroom_path(classroom)

      expect(response.body).to include(I18n.t('ui.buttons.compliment'))
      expect(response.body).not_to include(custom_compliment_path)

      create(:compliment_preset, user: create(:user, :teacher), title: '다른 교사 문구')

      get classroom_path(classroom)

      expect(response.body).not_to include(custom_compliment_path)

      create(:compliment_preset, user: teacher, title: '친구와 사이좋게 지냄')

      get classroom_path(classroom)

      expect(response.body).to include(custom_compliment_path)
    end

    it 'shows only active presets from the current user in the modal ordered by position' do
      second = create(:compliment_preset, user: teacher, title: '두 번째 칭찬', position: 2)
      first = create(:compliment_preset, user: teacher, title: '첫 번째 칭찬', position: 1)
      create(:compliment_preset, user: teacher, title: '비활성 칭찬', active: false)
      create(:compliment_preset, user: create(:user, :teacher), title: '다른 교사 칭찬')
      sign_in teacher

      get new_classroom_compliment_path(classroom, compliment: { receiver_id: student.id })

      expect(response).to have_http_status(:ok)
      expect(response.body.index(first.title)).to be < response.body.index(second.title)
      expect(response.body).not_to include('비활성 칭찬')
      expect(response.body).not_to include('다른 교사 칭찬')
    end

    it 'shows the same teacher presets in multiple assigned classrooms' do
      other_classroom = create(:classroom)
      other_student = create(:user, :student)
      create(:classroom_membership, classroom: other_classroom, user: teacher, role: 'teacher')
      create(:classroom_membership, classroom: other_classroom, user: other_student, role: 'student')
      create(:compliment_preset, user: teacher, title: '공통 개인 문구')
      sign_in teacher

      get classroom_path(classroom)
      expect(response.body).to include(new_classroom_compliment_path(classroom))

      get classroom_path(other_classroom)
      expect(response.body).to include(new_classroom_compliment_path(other_classroom))
    end

    it "shows each teacher only their own presets in the same classroom" do
      other_teacher = create(:user, :teacher)
      create(:classroom_membership, classroom: classroom, user: other_teacher, role: "teacher")
      create(:compliment_preset, user: teacher, title: "내 개인 문구")
      create(:compliment_preset, user: other_teacher, title: "다른 교사 문구")

      sign_in teacher
      get new_classroom_compliment_path(classroom, compliment: { receiver_id: student.id })

      expect(response.body).to include("내 개인 문구")
      expect(response.body).not_to include("다른 교사 문구")

      sign_out teacher
      sign_in other_teacher
      get new_classroom_compliment_path(classroom, compliment: { receiver_id: student.id })

      expect(response.body).to include("다른 교사 문구")
      expect(response.body).not_to include("내 개인 문구")
    end

    it 'keeps the compliment snapshot in the timeline after preset updates and deletion' do
      preset = create(:compliment_preset, user: teacher, title: '다른 친구를 위해 봉사함')
      sign_in teacher

      post classroom_compliments_path(classroom),
           params: { compliment: { receiver_id: student.id, compliment_preset_id: preset.id } },
           as: :json

      preset.update!(title: '수정된 칭찬')
      preset.update!(active: false)

      get activity_classroom_student_path(classroom, student)

      expect(response.body).to include('다른 친구를 위해 봉사함')
      expect(response.body).not_to include('수정된 칭찬')
    end

    it 'returns 409 for a duplicate request inside the duplicate window' do
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json

        expect(response).to have_http_status(:created)

        expect do
          post classroom_compliments_path(classroom),
               params: { compliment: { receiver_id: student.id } },
               as: :json
        end.not_to change(Compliment, :count)

        expect(response).to have_http_status(:conflict)
        expect(json_body).to eq('ok' => false, 'error' => 'duplicate_request')
        expect(student.reload.points).to eq(1)
      end
    end

    it 'returns a turbo stream conflict for a duplicate request inside the duplicate window' do
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

        expect(response).to have_http_status(:ok)

        expect do
          post classroom_compliments_path(classroom),
               params: { compliment: { receiver_id: student.id } },
               headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }
        end.not_to change(Compliment, :count)

        expect(response).to have_http_status(:conflict)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(student.reload.points).to eq(1)
      end
    end

    it 'allows the same teacher to create another compliment after the duplicate window' do
      sign_in teacher

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 2) do
        expect do
          post classroom_compliments_path(classroom),
               params: { compliment: { receiver_id: student.id } },
               as: :json
        end.to change(Compliment, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(student.reload.points).to eq(2)
      end
    end

    it "does not treat another teacher's compliment for the same student as a duplicate" do
      other_teacher = create(:user, :teacher)
      create(:classroom_membership, user: other_teacher, classroom: classroom, role: 'teacher')

      travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
        sign_in teacher
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json

        sign_out teacher
        sign_in other_teacher

        expect do
          post classroom_compliments_path(classroom),
               params: { compliment: { receiver_id: student.id } },
               as: :json
        end.to change(Compliment, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(student.reload.points).to eq(2)
      end
    end

    it 'rolls back both compliment creation and points increment when the transaction fails' do
      sign_in teacher

      allow_any_instance_of(User).to receive(:increment!).and_raise(
        ActiveRecord::RecordInvalid.new(student)
      )

      expect do
        post classroom_compliments_path(classroom),
             params: { compliment: { receiver_id: student.id } },
             as: :json
      end.not_to change(Compliment, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['ok']).to eq(false)
      expect(student.reload.points).to eq(0)
    end
  end
end
