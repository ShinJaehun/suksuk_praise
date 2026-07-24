require "rails_helper"

RSpec.describe "Compliment presets", type: :request do
  let(:teacher) { create(:user, :teacher) }

  it "allows a teacher without assigned classrooms to manage personal presets" do
    sign_in teacher

    get compliment_presets_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("자주 쓰는 칭찬 관리")
    expect(response.body).not_to include("교실을 선택")
    expect(response.body).not_to include("classroom_id")
  end

  it "allows an admin to manage only their own presets" do
    admin = create(:user, :admin)
    create(:compliment_preset, user: teacher, title: "선생님 문구")
    create(:compliment_preset, user: admin, title: "관리자 문구")
    sign_in admin

    get compliment_presets_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("관리자 문구")
    expect(response.body).not_to include("선생님 문구")
  end

  it "rejects a student" do
    student = create(:user, :student)
    sign_in student

    expect {
      post compliment_presets_path,
        params: { compliment_preset: { title: "학생 생성 시도" } }
    }.not_to change(ComplimentPreset, :count)

    expect(response).to redirect_to(root_path)
  end

  it "creates a preset owned by current_user and ignores submitted owner fields" do
    other_user = create(:user, :teacher)
    sign_in teacher

    expect {
      post compliment_presets_path,
        params: {
          compliment_preset: {
            user_id: other_user.id,
            classroom_id: create(:classroom).id,
            title: "친구와 사이좋게 지냄"
          }
        }
    }.to change { teacher.compliment_presets.active.count }.by(1)
      .and change { other_user.compliment_presets.count }.by(0)

    preset = teacher.compliment_presets.find_by!(title: "친구와 사이좋게 지냄")
    expect(preset.position).to eq(1)
    expect(response).to redirect_to(compliment_presets_path)
  end

  it "does not show another user's presets" do
    create(:compliment_preset, user: teacher, title: "내 문구")
    create(:compliment_preset, user: create(:user, :teacher), title: "다른 사용자 문구")
    sign_in teacher

    get compliment_presets_path

    expect(response.body).to include("내 문구")
    expect(response.body).not_to include("다른 사용자 문구")
  end

  it "does not allow editing another user's preset" do
    preset = create(:compliment_preset, user: create(:user, :teacher), title: "다른 사용자 문구")
    sign_in teacher

    patch compliment_preset_path(preset),
      params: { compliment_preset: { title: "조작된 문구" } }

    expect(response).to have_http_status(:not_found)
    expect(preset.reload.title).to eq("다른 사용자 문구")
  end

  it "does not allow deleting another user's preset" do
    preset = create(:compliment_preset, user: create(:user, :teacher), title: "다른 사용자 문구")
    sign_in teacher

    delete compliment_preset_path(preset)

    expect(response).to have_http_status(:not_found)
    expect(preset.reload).to be_active
  end

  it "does not move a preset to another user during update" do
    preset = create(:compliment_preset, user: teacher, title: "기존 칭찬")
    other_user = create(:user, :teacher)
    sign_in teacher

    patch compliment_preset_path(preset),
      params: { compliment_preset: { user_id: other_user.id, title: "수정된 칭찬" } }

    expect(response).to redirect_to(compliment_presets_path)
    expect(preset.reload.user).to eq(teacher)
    expect(preset.title).to eq("수정된 칭찬")
  end

  it "rejects blank titles" do
    sign_in teacher

    expect {
      post compliment_presets_path,
        params: { compliment_preset: { title: "" } }
    }.not_to change(ComplimentPreset, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("칭찬 문구")
  end

  it "rejects duplicate active titles for the same user" do
    create(:compliment_preset, user: teacher, title: "친구를 도움")
    sign_in teacher

    expect {
      post compliment_presets_path,
        params: { compliment_preset: { title: "친구를 도움" } }
    }.not_to change(ComplimentPreset, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("이미 등록")
  end

  it "allows another user to use the same title" do
    create(:compliment_preset, user: create(:user, :teacher), title: "친구를 도움")
    sign_in teacher

    expect {
      post compliment_presets_path,
        params: { compliment_preset: { title: "친구를 도움" } }
    }.to change { teacher.compliment_presets.active.count }.by(1)
  end

  it "rejects a sixth active preset per user" do
    create_list(:compliment_preset, 5, user: teacher)
    sign_in teacher

    expect {
      post compliment_presets_path,
        params: { compliment_preset: { title: "여섯 번째 칭찬" } }
    }.not_to change(ComplimentPreset, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("최대 5개")
  end

  it "does not count inactive presets toward the limit" do
    create_list(:compliment_preset, 5, user: teacher, active: false)
    sign_in teacher

    expect {
      post compliment_presets_path,
        params: { compliment_preset: { title: "활성 칭찬" } }
    }.to change { teacher.compliment_presets.active.count }.by(1)
  end

  it "shows active presets in user position order" do
    create(:compliment_preset, user: teacher, title: "두 번째", position: 2)
    create(:compliment_preset, user: teacher, title: "첫 번째", position: 1)
    create(:compliment_preset, user: create(:user, :teacher), title: "다른 사용자")
    sign_in teacher

    get compliment_presets_path

    expect(response.body.index("첫 번째")).to be < response.body.index("두 번째")
    expect(response.body).not_to include("다른 사용자")
  end

  it "updates and soft deletes through global routes" do
    preset = create(:compliment_preset, user: teacher, title: "수정 전")
    sign_in teacher

    get edit_compliment_preset_path(preset)
    expect(response).to have_http_status(:ok)

    patch compliment_preset_path(preset),
      params: { compliment_preset: { title: "수정 후" } }

    expect(response).to redirect_to(compliment_presets_path)
    expect(preset.reload.title).to eq("수정 후")

    expect {
      delete compliment_preset_path(preset)
    }.not_to change(ComplimentPreset, :count)

    expect(preset.reload).not_to be_active
    expect(response).to redirect_to(compliment_presets_path)
  end

  it "keeps historical compliment snapshots after preset deactivation" do
    classroom = create(:classroom)
    student = create(:user, :student, name: "김학생")
    preset = create(:compliment_preset, user: teacher, title: "다른 친구를 위해 봉사함")
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    create(:classroom_membership, classroom: classroom, user: student, role: "student")
    create(:compliment, classroom: classroom, giver: teacher, receiver: student, compliment_preset: preset, reason: preset.title)
    sign_in teacher

    delete compliment_preset_path(preset)
    get compliments_path(kind: "custom")

    expect(response.body).to include("다른 친구를 위해 봉사함")
  end
end
