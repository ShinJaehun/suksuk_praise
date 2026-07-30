require "rails_helper"
require "stringio"

RSpec.describe ClassroomStudents::RosterUpdate do
  let(:classroom) { create(:classroom) }

  def create_student_membership(number:, status: "active", **user_attributes)
    student = create(
      :user,
      :student,
      { gender: "boy", avatar_key: "boy01" }.merge(user_attributes)
    )
    membership = create(
      :classroom_membership,
      classroom: classroom,
      user: student,
      status: status,
      student_number: number
    )
    [student, membership]
  end

  def call_workflow(memberships:, rows:)
    described_class.call(
      classroom: classroom,
      memberships: memberships,
      rows: rows
    )
  end

  it "updates student profile fields and the membership number together" do
    student, membership = create_student_membership(number: 1, name: "수정 전")

    result = call_workflow(
      memberships: [membership],
      rows: {
        membership.id => {
          student_number: "7",
          name: "수정 후",
          gender: "girl",
          avatar_key: "girl02"
        }
      }
    )

    expect(result).to be_success
    expect(membership.reload.student_number).to eq(7)
    expect(student.reload.attributes.values_at("name", "gender", "avatar_key")).to eq(
      ["수정 후", "girl", "girl02"]
    )
  end

  it "stores a blank student number as nil" do
    student, membership = create_student_membership(number: 7)

    result = call_workflow(
      memberships: [membership],
      rows: { membership.id => { student_number: "", name: student.name } }
    )

    expect(result).to be_success
    expect(membership.reload.student_number).to be_nil
  end

  it "rejects duplicate final numbers among edited active students" do
    first, first_membership = create_student_membership(number: 1)
    second, second_membership = create_student_membership(number: 2)

    result = call_workflow(
      memberships: [first_membership, second_membership],
      rows: {
        first_membership.id => { student_number: "2", name: first.name },
        second_membership.id => { student_number: "2", name: second.name }
      }
    )

    expect(result).not_to be_success
    expect(result.row_errors.keys).to contain_exactly(
      first_membership.id.to_s,
      second_membership.id.to_s
    )
    expect([first_membership, second_membership].map { |item| item.reload.student_number }).to eq([1, 2])
  end

  it "rejects a number used by an unedited active student" do
    student, membership = create_student_membership(number: 1)
    _unedited_student, unedited_membership = create_student_membership(number: 2)

    result = call_workflow(
      memberships: [membership],
      rows: { membership.id => { student_number: "2", name: student.name } }
    )

    expect(result).not_to be_success
    expect(result.row_errors[membership.id.to_s]).to include(
      I18n.t("students.members.update_names.duplicate_student_number", number: 2)
    )
    expect(membership.reload.student_number).to eq(1)
    expect(unedited_membership.reload.student_number).to eq(2)
  end

  it "swaps two active student numbers" do
    first, first_membership = create_student_membership(number: 1)
    second, second_membership = create_student_membership(number: 2)

    result = call_workflow(
      memberships: [first_membership, second_membership],
      rows: {
        first_membership.id => { student_number: "2", name: first.name },
        second_membership.id => { student_number: "1", name: second.name }
      }
    )

    expect(result).to be_success
    expect([first_membership, second_membership].map { |item| item.reload.student_number }).to eq([2, 1])
  end

  it "supports an active student number cycle" do
    records = [1, 2, 3].map { |number| create_student_membership(number: number) }
    memberships = records.map(&:last)
    rows = memberships.each_with_index.to_h do |membership, index|
      next_number = [2, 3, 1][index]
      [membership.id, { student_number: next_number.to_s, name: membership.user.name }]
    end

    result = call_workflow(memberships: memberships, rows: rows)

    expect(result).to be_success
    expect(memberships.map { |item| item.reload.student_number }).to eq([2, 3, 1])
  end

  it "rejects a membership outside the supplied editable collection" do
    student, membership = create_student_membership(number: 1)
    other_student, other_membership = create_student_membership(number: 2)

    result = call_workflow(
      memberships: [membership],
      rows: {
        membership.id => { name: "변경 금지" },
        other_membership.id => { name: "외부 변경 금지" }
      }
    )

    expect(result).not_to be_success
    expect(result.error_key).to eq(:invalid_membership)
    expect(student.reload.name).not_to eq("변경 금지")
    expect(other_student.reload.name).not_to eq("외부 변경 금지")
  end

  it "rolls back all user and membership changes when a later save fails" do
    first, first_membership = create_student_membership(number: 1, name: "첫 원본")
    second, second_membership = create_student_membership(number: 2, name: "둘 원본")
    calls = 0
    allow_any_instance_of(User).to receive(:save!).and_wrap_original do |method, *args|
      calls += 1
      if calls == 2
        method.receiver.errors.add(:base, "user failed")
        raise ActiveRecord::RecordInvalid.new(method.receiver)
      end

      method.call(*args)
    end

    result = call_workflow(
      memberships: [first_membership, second_membership],
      rows: {
        first_membership.id => { student_number: "2", name: "첫 변경" },
        second_membership.id => { student_number: "1", name: "둘 변경" }
      }
    )

    expect(result).not_to be_success
    expect([first, second].map { |student| student.reload.name }).to eq(["첫 원본", "둘 원본"])
    expect([first_membership, second_membership].map { |item| item.reload.student_number }).to eq([1, 2])
  end

  it "preserves a legacy mismatched avatar when gender is unchanged" do
    student, membership = create_student_membership(number: 7, name: "기존")
    student.update_column(:avatar_key, "girl01")

    result = call_workflow(
      memberships: [membership],
      rows: {
        membership.id => {
          student_number: "8",
          name: "수정",
          gender: "boy",
          avatar_key: "girl01"
        }
      }
    )

    expect(result).to be_success
    expect(student.reload.attributes.values_at("name", "gender", "avatar_key")).to eq(
      ["수정", "boy", "girl01"]
    )
  end

  it "rejects a different mismatched avatar when gender is unchanged" do
    student, membership = create_student_membership(number: 7, name: "기존")

    result = call_workflow(
      memberships: [membership],
      rows: {
        membership.id => {
          student_number: "8",
          name: "변경 금지",
          gender: "boy",
          avatar_key: "girl07"
        }
      }
    )

    expect(result).not_to be_success
    expect(result.row_errors[membership.id.to_s]).to include(
      I18n.t("students.members.update_names.invalid_avatar")
    )
    expect(student.reload.attributes.values_at("name", "gender", "avatar_key")).to eq(
      ["기존", "boy", "boy01"]
    )
  end

  it "keeps a submitted valid avatar after a gender change" do
    student, membership = create_student_membership(number: 1)

    result = call_workflow(
      memberships: [membership],
      rows: {
        membership.id => {
          name: student.name,
          gender: "girl",
          avatar_key: "girl03"
        }
      }
    )

    expect(result).to be_success
    expect(student.reload.attributes.values_at("gender", "avatar_key")).to eq(["girl", "girl03"])
  end

  it "uses the deterministic fallback after a gender change" do
    student, membership = create_student_membership(number: 1)

    result = call_workflow(
      memberships: [membership],
      rows: {
        membership.id => {
          name: student.name,
          gender: "girl",
          avatar_key: "boy01"
        }
      }
    )

    expect(result).to be_success
    expect(student.reload.avatar_key).to eq(User.avatar_keys_for("girl").first)
  end

  it "does not detach an uploaded avatar" do
    student, membership = create_student_membership(number: 1)
    student.avatar.attach(
      io: StringIO.new("avatar"),
      filename: "avatar.png",
      content_type: "image/png"
    )

    result = call_workflow(
      memberships: [membership],
      rows: {
        membership.id => {
          student_number: "2",
          name: "첨부 유지",
          gender: "girl",
          avatar_key: "girl01"
        }
      }
    )

    expect(result).to be_success
    expect(student.reload.avatar).to be_attached
  end

  it "converts a database unique conflict into a failed result" do
    first, first_membership = create_student_membership(number: 1)
    second, second_membership = create_student_membership(number: 2)
    allow_any_instance_of(ClassroomMembership).to receive(:save!)
      .and_raise(ActiveRecord::RecordNotUnique)

    result = call_workflow(
      memberships: [first_membership, second_membership],
      rows: {
        first_membership.id => { student_number: "2", name: first.name },
        second_membership.id => { student_number: "1", name: second.name }
      }
    )

    expect(result).not_to be_success
    expect(result.error_key).to eq(:failure)
    expect(result.row_errors.keys).to contain_exactly(
      first_membership.id.to_s,
      second_membership.id.to_s
    )
    expect([first_membership, second_membership].map { |item| item.reload.student_number }).to eq([1, 2])
  end

  it "preserves submitted raw values and row errors after validation fails" do
    student, membership = create_student_membership(number: 1)

    result = call_workflow(
      memberships: [membership],
      rows: {
        membership.id => {
          student_number: "abc",
          name: student.name,
          gender: "boy",
          avatar_key: "boy01"
        }
      }
    )

    expect(result).not_to be_success
    expect(result.rows[membership.id.to_s]["student_number"]).to eq("abc")
    expect(result.row_errors[membership.id.to_s]).to include(
      I18n.t("students.members.update_names.invalid_student_number")
    )
  end
end
