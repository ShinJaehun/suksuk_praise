require "rails_helper"

RSpec.describe Dashboard::ClassroomAnalytics, type: :service do
  let(:classroom) { create(:classroom) }
  let(:other_classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }
  let(:template) { create(:coupon_template, created_by: teacher) }
  let(:range) { Time.zone.local(2026, 7, 13).beginning_of_day..Time.zone.local(2026, 7, 15).end_of_day }

  def add_student(target_classroom, status: "active", created_at: Time.current)
    student = create(:user, :student)
    create(:classroom_membership,
      classroom: target_classroom,
      user: student,
      role: "student",
      status: status,
      created_at: created_at)
    student
  end

  def add_coupon_event(student:, target_classroom:, action:, occurred_at:)
    coupon = create(:user_coupon,
      user: student,
      classroom: target_classroom,
      coupon_template: template,
      issued_by: teacher,
      issuance_basis: "manual",
      issued_at: occurred_at)
    create(:coupon_event,
      action: action,
      actor: teacher,
      user_coupon: coupon,
      classroom: target_classroom,
      coupon_template: template,
      created_at: occurred_at)
  end

  it "groups classroom activity for active students while preserving membership order" do
    first = add_student(classroom, created_at: 2.days.ago)
    second = add_student(classroom, created_at: 1.day.ago)
    zero = add_student(classroom)
    inactive = add_student(classroom, status: "inactive")
    outsider = add_student(other_classroom)

    2.times do |index|
      create(:compliment,
        classroom: classroom,
        giver: teacher,
        receiver: first,
        given_at: Time.zone.local(2026, 7, 13, 10 + index))
    end
    create(:compliment,
      classroom: classroom,
      giver: teacher,
      receiver: second,
      given_at: Time.zone.local(2026, 7, 14, 10))
    create(:compliment,
      classroom: classroom,
      giver: teacher,
      receiver: inactive,
      given_at: Time.zone.local(2026, 7, 14, 10))
    create(:compliment,
      classroom: other_classroom,
      giver: teacher,
      receiver: outsider,
      given_at: Time.zone.local(2026, 7, 14, 10))
    create(:compliment,
      classroom: classroom,
      giver: teacher,
      receiver: first,
      given_at: Time.zone.local(2026, 7, 12, 23, 59))
    create(:compliment,
      classroom: classroom,
      giver: teacher,
      receiver: first,
      given_at: Time.zone.local(2026, 7, 16, 0, 0))

    2.times do |index|
      add_coupon_event(
        student: first,
        target_classroom: classroom,
        action: "issued",
        occurred_at: Time.zone.local(2026, 7, 13, 12 + index)
      )
    end
    add_coupon_event(
      student: first,
      target_classroom: classroom,
      action: "used",
      occurred_at: Time.zone.local(2026, 7, 14, 12)
    )
    add_coupon_event(
      student: outsider,
      target_classroom: other_classroom,
      action: "issued",
      occurred_at: Time.zone.local(2026, 7, 14, 12)
    )
    add_coupon_event(
      student: first,
      target_classroom: classroom,
      action: "issued",
      occurred_at: Time.zone.local(2026, 7, 16, 0, 0)
    )

    result = described_class.call(classroom: classroom, time_range: range, metric: "compliments")

    expect(result.student_rows.map { |row| row[:student] }).to eq([first, second, zero])
    expect(result.student_rows.map { |row| row.slice(:compliments_count, :issued_count, :used_count) }).to eq([
      { compliments_count: 2, issued_count: 2, used_count: 1 },
      { compliments_count: 1, issued_count: 0, used_count: 0 },
      { compliments_count: 0, issued_count: 0, used_count: 0 }
    ])
    expect(result.student_rows.map { |row| row[:bar_percent] }).to eq([100, 50, 0])
    expect(result.summary).to eq(
      compliments_count: 3,
      issued_count: 2,
      used_count: 1,
      zero_compliment_students_count: 1
    )
  end

  it "changes selected values and percentages with the metric" do
    first = add_student(classroom, created_at: 1.day.ago)
    second = add_student(classroom)
    2.times do |index|
      add_coupon_event(
        student: first,
        target_classroom: classroom,
        action: "issued",
        occurred_at: Time.zone.local(2026, 7, 13, 10 + index)
      )
    end
    add_coupon_event(
      student: second,
      target_classroom: classroom,
      action: "issued",
      occurred_at: Time.zone.local(2026, 7, 13, 12)
    )

    result = described_class.call(classroom: classroom, time_range: range, metric: "issued")

    expect(result.student_rows.map { |row| row[:selected_metric_count] }).to eq([2, 1])
    expect(result.student_rows.map { |row| row[:bar_percent] }).to eq([100, 50])
  end

  it "returns zero percentages when every selected value is zero" do
    add_student(classroom)
    add_student(classroom)

    result = described_class.call(classroom: classroom, time_range: range, metric: "used")

    expect(result.student_rows.map { |row| row[:selected_metric_count] }).to eq([0, 0])
    expect(result.student_rows.map { |row| row[:bar_percent] }).to eq([0, 0])
  end
end
