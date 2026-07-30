require 'rails_helper'

RSpec.describe Classrooms::ShowContext do
  include ActiveSupport::Testing::TimeHelpers

  let(:classroom) { create(:classroom) }
  let(:teacher) { create(:user, :teacher) }

  def build_context(
    include_student_alerts: true,
    include_compliment_presets: true
  )
    described_class.new(
      classroom: classroom,
      current_user: teacher,
      include_student_alerts: include_student_alerts,
      include_compliment_presets: include_compliment_presets
    )
  end

  it 'returns active students in roster order and excludes other or inactive students' do
    second = create(:user, :student, name: '둘째')
    first = create(:user, :student, name: '첫째')
    unnumbered = create(:user, :student, name: '미지정')
    inactive = create(:user, :student)
    other = create(:user, :student)
    second_membership = create(:classroom_membership, classroom: classroom, user: second, student_number: 2)
    first_membership = create(:classroom_membership, classroom: classroom, user: first, student_number: 1)
    unnumbered_membership = create(:classroom_membership, classroom: classroom, user: unnumbered)
    create(:classroom_membership, classroom: classroom, user: inactive, status: 'inactive')
    create(:classroom_membership, classroom: create(:classroom), user: other)

    context = build_context

    expect(context.student_memberships.to_a).to eq(
      [first_membership, second_membership, unnumbered_membership]
    )
    expect(context.students.pluck(:id)).to contain_exactly(first.id, second.id, unnumbered.id)
  end

  it 'returns active homeroom teachers in the existing order' do
    later = create(:user, :teacher, name: '나교사')
    earlier = create(:user, :teacher, name: '가교사')
    inactive = create(:user, :teacher, name: '비활성', active: false)
    create(:classroom_membership, classroom: classroom, user: later, role: 'teacher')
    create(:classroom_membership, classroom: classroom, user: earlier, role: 'teacher')
    create(:classroom_membership, classroom: classroom, user: inactive, role: 'teacher')

    expect(build_context.homeroom_teachers.to_a).to eq([earlier, later])
  end

  it 'returns enabled and currently refreshable compliment king periods' do
    classroom.update!(weekly_compliment_king_enabled: true, monthly_compliment_king_enabled: true)
    allow(classroom).to receive(:compliment_king_refresh_available_for?) do |period|
      %w[daily monthly].include?(period)
    end

    context = build_context

    expect(context.enabled_compliment_king_periods).to eq(%w[daily weekly monthly])
    expect(context.refreshable_compliment_king_periods).to eq(%w[daily monthly])
    expect(context.compliment_king_period_cards.map { |card| card[:period] }).to eq(%w[daily weekly monthly])
  end

  it 'returns pending coupon and unread student message ids as sets for this classroom' do
    classroom.update!(message_policy: 'student_initiated')
    student = create(:user, :student)
    other_student = create(:user, :student)
    create(:classroom_membership, classroom: classroom, user: student)
    other_classroom = create(:classroom, message_policy: 'student_initiated')
    create(:classroom_membership, classroom: other_classroom, user: other_student)

    create(
      :classroom_membership,
      classroom: other_classroom,
      user: teacher,
      role: 'teacher'
    )

    create(:classroom_membership, classroom: classroom, user: teacher, role: 'teacher')
    template = create(:coupon_template, created_by: teacher)
    coupon = create(
      :user_coupon,
      classroom: classroom,
      user: student,
      coupon_template: template,
      issued_by: teacher
    )
    other_coupon = create(
      :user_coupon,
      classroom: other_classroom,
      user: other_student,
      coupon_template: template,
      issued_by: teacher
    )
    create(:coupon_use_request, user_coupon: coupon)
    create(:coupon_use_request, user_coupon: other_coupon)
    create(:user_message, classroom: classroom, sender: student, recipient: teacher)
    create(:user_message, classroom: other_classroom, sender: other_student, recipient: teacher)

    context = build_context

    expect(context.pending_coupon_use_request_student_ids).to eq(Set[student.id])
    expect(context.unread_student_message_student_ids).to eq(Set[student.id])
  end

  it 'returns empty alert sets when student alerts are excluded' do
    context = build_context(include_student_alerts: false)

    expect(context.pending_coupon_use_request_student_ids).to eq(Set.new)
    expect(context.unread_student_message_student_ids).to eq(Set.new)
  end

  it 'returns active ordered presets only when requested' do
    later = create(:compliment_preset, user: teacher, position: 2)
    earlier = create(:compliment_preset, user: teacher, position: 1)
    create(:compliment_preset, user: teacher, active: false)

    expect(build_context.active_compliment_presets.to_a).to eq([earlier, later])
    expect(build_context(include_compliment_presets: false).active_compliment_presets).to be_nil
  end

  it "groups today's compliments for active students and excludes other classrooms" do
    student = create(:user, :student)
    other_student = create(:user, :student)
    create(:classroom_membership, classroom: classroom, user: student)
    other_classroom = create(:classroom)
    create(:classroom_membership, classroom: other_classroom, user: other_student)

    travel_to Time.zone.local(2026, 4, 7, 10, 0, 0) do
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: Time.current)
      create(:compliment, classroom: classroom, giver: teacher, receiver: student, given_at: 1.day.ago)
      create(:compliment, classroom: other_classroom, giver: teacher, receiver: other_student, given_at: Time.current)

      expect(build_context.today_compliment_counts_by_student_id).to eq(student.id => 1)
    end
  end

  it 'returns empty results for an empty classroom' do
    context = build_context

    expect(context.student_memberships).to be_empty
    expect(context.students).to be_empty
    expect(context.homeroom_teachers).to be_empty
    expect(context.pending_coupon_use_request_student_ids).to eq(Set.new)
    expect(context.unread_student_message_student_ids).to eq(Set.new)
    expect(context.today_compliment_counts_by_student_id).to eq({})
  end
end
