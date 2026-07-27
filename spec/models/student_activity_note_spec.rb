require 'rails_helper'

RSpec.describe StudentActivityNote, type: :model do
  it 'copies context from a compliment' do
    source = create(:compliment)
    note = create(:student_activity_note, source: source)

    expect(note.student).to eq(source.receiver)
    expect(note.classroom).to eq(source.classroom)
    expect(note.occurred_at).to be_within(1.second).of(source.given_at)
  end

  it 'copies context from a coupon event' do
    source = create(:coupon_event)
    note = create(:student_activity_note, source: source)

    expect(note.student).to eq(source.user_coupon.user)
    expect(note.classroom).to eq(source.classroom)
    expect(note.occurred_at).to be_within(1.second).of(source.created_at)
  end

  it 'validates body presence and length' do
    expect(build(:student_activity_note, body: '')).to be_invalid
    expect(build(:student_activity_note, body: 'a' * 1_000)).to be_valid
    expect(build(:student_activity_note, body: 'a' * 1_001)).to be_invalid
  end

  it 'allows only supported source types' do
    compliment = create(:compliment)
    coupon_event = create(:coupon_event)
    unsupported_note = build(:student_activity_note, source: build(:school))

    expect(build(:student_activity_note, source: compliment)).to be_valid
    expect(build(:student_activity_note, source: coupon_event)).to be_valid
    expect(unsupported_note).to be_invalid
    expect(unsupported_note.errors[:source_type]).to be_present
  end

  it 'allows one note per source and author' do
    source = create(:compliment)
    author = create(:user, :teacher)
    create(:student_activity_note, source: source, author: author)

    expect(build(:student_activity_note, source: source, author: author)).to be_invalid
    expect(build(:student_activity_note, source: source, author: create(:user, :teacher))).to be_valid
    expect(build(:student_activity_note, source: create(:compliment), author: author)).to be_valid
  end

  it 'keeps source context readonly after creation' do
    note = create(:student_activity_note)
    original = note.attributes.slice(
      'source_type', 'source_id', 'student_id', 'classroom_id', 'author_id', 'occurred_at'
    )

    readonly_changes = {
      source: create(:compliment),
      student: create(:user, :student),
      classroom: create(:classroom),
      author: create(:user, :teacher),
      occurred_at: 1.day.from_now
    }

    readonly_changes.each do |attribute, value|
      expect do
        note.reload.update!(attribute => value)
      end.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end

    note.reload.update!(body: '수정된 메모')
    expect(note.reload.attributes.slice(*original.keys)).to eq(original)
    expect(note.body).to eq('수정된 메모')
  end

  it 'destroys notes with their source' do
    compliment = create(:compliment)
    coupon_event = create(:coupon_event)
    create(:student_activity_note, source: compliment)
    create(:student_activity_note, source: coupon_event)

    expect { compliment.destroy! }.to change(described_class, :count).by(-1)
    expect { coupon_event.destroy! }.to change(described_class, :count).by(-1)
  end
end
