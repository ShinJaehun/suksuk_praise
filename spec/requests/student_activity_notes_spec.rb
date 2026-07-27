require "rails_helper"

RSpec.describe "Student activity notes", type: :request do
  include ActionView::RecordIdentifier

  let(:classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }
  let(:student) { create(:user, :student) }
  let(:compliment) { create(:compliment, classroom: classroom, receiver: student) }
  let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }

  before do
    create(:classroom_membership, classroom: classroom, user: teacher, role: "teacher")
    create(
      :classroom_membership,
      classroom: classroom,
      user: student,
      role: "student",
      status: "active"
    )
  end

  def coupon_event
    @coupon_event ||= begin
      coupon = create(:user_coupon, classroom: classroom, user: student)
      create(:coupon_event, user_coupon: coupon, classroom: classroom, coupon_template: coupon.coupon_template)
    end
  end

  it "renders matching new forms for persisted supported sources" do
    sign_in teacher

    [compliment, coupon_event].each do |source|
      get new_student_activity_note_path(source_type: source.class.name, source_id: source.id)

      document = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:ok)
      frame = document.at_css(%(turbo-frame[id="#{dom_id(source, :activity_notes)}"]))
      expect(frame).to be_present
      expect(frame.at_css("textarea[name='student_activity_note[body]']")).to be_present
      form = frame.at_css("form")
      expect(form).to be_present
      expect(form["action"]).to include(
        student_activity_notes_path,
        "source_type=#{source.class.name}",
        "source_id=#{source.id}"
      )
    end
  end

  it "returns not found for unsupported source types" do
    sign_in teacher

    %w[User Kernel Unknown].each do |source_type|
      get new_student_activity_note_path(source_type: source_type, source_id: compliment.id)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "cancels back into the matching source frame without the return anchor" do
    frame_id = dom_id(compliment, :activity_notes)
    return_to = "#{compliment_events_path(period: "all_time")}##{frame_id}"
    sign_in teacher

    get new_student_activity_note_path(
      source_type: "Compliment",
      source_id: compliment.id,
      return_to: return_to
    )

    frame = Nokogiri::HTML(response.body).at_css(%(turbo-frame[id="#{frame_id}"]))
    cancel_link = frame.at_css('[data-activity-note-action="cancel"]')
    cancel_uri = URI.parse(cancel_link["href"])
    expect(cancel_uri.path).to eq(compliment_events_path)
    expect(Rack::Utils.parse_nested_query(cancel_uri.query)).to include("period" => "all_time")
    expect(cancel_uri.fragment).to be_nil
    expect(cancel_link["data-turbo-frame"]).to eq(frame_id)
    expect(cancel_link["data-turbo-frame"]).not_to eq("_top")
  end

  it "creates compliment and coupon event notes from source context" do
    sign_in teacher

    [compliment, coupon_event].each do |source|
      expect {
        post student_activity_notes_path(source_type: source.class.name, source_id: source.id),
          params: {
            student_activity_note: {
              body: "관찰 메모",
              student_id: create(:user, :student).id,
              classroom_id: create(:classroom).id,
              author_id: create(:user, :teacher).id,
              source_type: "User",
              source_id: teacher.id,
              occurred_at: 1.year.ago
            }
          },
          headers: turbo_headers
      }.to change(StudentActivityNote, :count).by(1)

      note = StudentActivityNote.order(:id).last
      expected_student = source.is_a?(Compliment) ? source.receiver : source.user_coupon.user
      expected_time = source.is_a?(Compliment) ? source.given_at : source.created_at
      expect(note.attributes.slice("source_type", "source_id", "student_id", "classroom_id", "author_id")).to eq(
        "source_type" => source.class.name,
        "source_id" => source.id,
        "student_id" => expected_student.id,
        "classroom_id" => source.classroom_id,
        "author_id" => teacher.id
      )
      expect(note.occurred_at).to be_within(1.second).of(expected_time)
      expect(response.body).to include(
        %(turbo-stream action="update" target="#{dom_id(source, :activity_notes)}")
      )
    end
  end

  it "rerenders validation and duplicate errors with 422" do
    sign_in teacher

    expect {
      post student_activity_notes_path(source_type: "Compliment", source_id: compliment.id),
        params: { student_activity_note: { body: "" } },
        headers: turbo_headers
    }.not_to change(StudentActivityNote, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    frame = Nokogiri::HTML(response.body).at_css(
      %(turbo-frame[id="#{dom_id(compliment, :activity_notes)}"])
    )
    expect(frame).to be_present
    expect(frame.at_css("textarea[name='student_activity_note[body]']")).to be_present
    expect(frame.at_css("p.text-rose-600")&.text).to be_present

    expect {
      post student_activity_notes_path(source_type: "Compliment", source_id: compliment.id),
        params: { student_activity_note: { body: "a" * 1_001 } }
    }.not_to change(StudentActivityNote, :count)
    expect(response).to have_http_status(:unprocessable_entity)

    create(:student_activity_note, source: compliment, author: teacher)
    post student_activity_notes_path(source_type: "Compliment", source_id: compliment.id),
      params: { student_activity_note: { body: "중복" } }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rerenders an invalid Turbo update without changing the note" do
    note = create(:student_activity_note, source: compliment, author: teacher, body: "기존 메모")
    sign_in teacher

    patch student_activity_note_path(note),
      params: { student_activity_note: { body: "a" * 1_001 } },
      headers: turbo_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(note.reload.body).to eq("기존 메모")
    frame = Nokogiri::HTML(response.body).at_css(
      %(turbo-frame[id="#{dom_id(compliment, :activity_notes)}"])
    )
    expect(frame).to be_present
    expect(frame.at_css("textarea[name='student_activity_note[body]']")).to be_present
  end

  it "lets the current author update and destroy only the body" do
    note = create(:student_activity_note, source: compliment, author: teacher)
    original_context = note.attributes.slice("source_type", "source_id", "student_id", "classroom_id", "author_id", "occurred_at")
    sign_in teacher

    patch student_activity_note_path(note),
      params: { student_activity_note: { body: "수정됨", author_id: student.id } },
      headers: turbo_headers

    expect(note.reload.body).to eq("수정됨")
    expect(note.attributes.slice(*original_context.keys)).to eq(original_context)
    expect(response.body).to include(%(target="#{dom_id(compliment, :activity_notes)}"))

    expect {
      delete student_activity_note_path(note), headers: turbo_headers
    }.to change(StudentActivityNote, :count).by(-1)
    expect(response.body).to include(%(target="#{dom_id(compliment, :activity_notes)}"))
  end

  it "allows an admin but blocks another teacher, student, and a former author" do
    note = create(:student_activity_note, source: compliment, author: teacher)
    outsider = create(:user, :teacher)

    [outsider, student].each do |actor|
      sign_in actor
      patch student_activity_note_path(note), params: { student_activity_note: { body: "차단" } }
      expect(response).to redirect_to(root_path)
    end

    teacher.classroom_memberships.find_by!(classroom: classroom, role: "teacher").destroy!
    sign_in teacher
    delete student_activity_note_path(note)
    expect(response).to redirect_to(root_path)

    sign_in create(:user, :admin)
    patch student_activity_note_path(note), params: { student_activity_note: { body: "관리자 수정" } }
    expect(note.reload.body).to eq("관리자 수정")

    admin_destroy_note = create(
      :student_activity_note,
      source: create(:compliment, classroom: classroom),
      author: teacher
    )
    expect {
      delete student_activity_note_path(admin_destroy_note), headers: turbo_headers
    }.to change(StudentActivityNote, :count).by(-1)
    expect(response.body).to include(
      %(target="#{dom_id(admin_destroy_note.source, :activity_notes)}")
    )
  end

  it "does not allow an outside teacher or student to create notes" do
    outside_teacher = create(:user, :teacher)
    sign_in outside_teacher
    get new_student_activity_note_path(source_type: "Compliment", source_id: compliment.id)
    expect(response).to have_http_status(:not_found)

    [outside_teacher, student].each do |actor|
      sign_in actor
      post student_activity_notes_path(source_type: "Compliment", source_id: compliment.id),
        params: { student_activity_note: { body: "차단" } }
      expect(StudentActivityNote.count).to eq(0)
    end
  end

  it "uses only a safe local return path for HTML redirects" do
    sign_in teacher

    post student_activity_notes_path(
      source_type: "Compliment",
      source_id: compliment.id,
      return_to: "https://example.com/escape"
    ), params: { student_activity_note: { body: "메모" } }

    expect(response).to redirect_to(compliment_events_path)
  end
end
