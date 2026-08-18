class Classrooms::StudentCardAlertStatesController < ApplicationController
  before_action :authenticate_user!

  def show
    classroom = Classroom.find(params[:classroom_id])
    authorize classroom, :update?

    active_student_ids = classroom.classroom_memberships.student.active.select(:user_id)
    pending_coupon_request_student_ids = CouponUseRequest
      .pending
      .where(classroom_id: classroom.id, student_id: active_student_ids)
      .distinct
      .pluck(:student_id)
    unread_student_message_student_ids =
      if classroom.student_messages_enabled?
        UserMessage
          .unread_student_messages
          .where(classroom_id: classroom.id, sender_id: active_student_ids)
          .distinct
          .pluck(:sender_id)
      else
        []
      end

    render json: {
      pending_coupon_request_student_ids: pending_coupon_request_student_ids,
      unread_student_message_student_ids: unread_student_message_student_ids
    }
  end
end
