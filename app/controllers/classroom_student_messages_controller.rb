class ClassroomStudentMessagesController < ApplicationController
  include UserShowDataLoader
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_classroom
  before_action :set_student

  def create
    @message = UserMessage.new(
      classroom: @classroom,
      sender: current_user,
      recipient: @student,
      body: message_params[:body]
    )
    authorize @message

    if @message.save
      load_managed_message_section!

      respond_to do |format|
        format.html { redirect_to classroom_student_path(@classroom, @student), notice: "메시지를 전송했습니다.", status: :see_other }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html do
          redirect_to classroom_student_path(@classroom, @student),
            alert: @message.errors.full_messages.to_sentence,
            status: :see_other
        end
        format.turbo_stream do
          load_managed_message_section!(message: @message)
          render :create, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:classroom_id])
  end

  def set_student
    @student = User.find(params[:student_id])
    raise ActiveRecord::RecordNotFound unless @student.student?
    raise ActiveRecord::RecordNotFound unless @classroom.classroom_memberships.exists?(user_id: @student.id, role: "student")
  end

  def message_params
    params.require(:user_message).permit(:body)
  end

  def load_managed_message_section!(message: nil)
    load_user_show_data!(
      user: @student,
      classroom: @classroom,
      include_recent_issued: true,
      recent_in_classroom: true
    )

    @new_message = message || UserMessage.new
    @message_section_dom_id = dom_id(@student, :message_section)
  end
end
