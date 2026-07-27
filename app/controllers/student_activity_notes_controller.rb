class StudentActivityNotesController < ApplicationController
  include ActionView::RecordIdentifier

  SOURCE_CLASSES = {
    "CouponEvent" => CouponEvent,
    "Compliment" => Compliment
  }.freeze

  before_action :authenticate_user!
  before_action :set_source, only: %i[new create]
  before_action :set_note, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  def new
    @note = @source.student_activity_notes.build(author: current_user)
    authorize @note, :create?
    prepare_return_to
  end

  def create
    @note = @source.student_activity_notes.build(note_params)
    @note.author = current_user
    authorize @note, :create?
    prepare_return_to

    if @note.save
      respond_with_panel(t("student_activity_notes.notices.created"))
    else
      render :new, formats: :html, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @note.errors.add(:base, t("student_activity_notes.errors.duplicate"))
    render :new, formats: :html, status: :unprocessable_entity
  end

  def edit
    authorize @note, :update?
    prepare_return_to
  end

  def update
    authorize @note, :update?
    prepare_return_to

    if @note.update(note_params)
      respond_with_panel(t("student_activity_notes.notices.updated"))
    else
      render :edit, formats: :html, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @note, :destroy?
    prepare_return_to
    @note.destroy!
    respond_with_panel(t("student_activity_notes.notices.destroyed"))
  end

  private

  def set_source
    source_class = SOURCE_CLASSES.fetch(params[:source_type]) { raise ActiveRecord::RecordNotFound }
    raise ActiveRecord::RecordNotFound unless StudentActivityNote::SOURCE_TYPES.include?(source_class.name)

    @source = policy_scope(source_class).find(params[:source_id])
  end

  def set_note
    @note = StudentActivityNote.find(params[:id])
    @source = @note.source
  end

  def note_params
    params.require(:student_activity_note).permit(:body)
  end

  def prepare_return_to
    @return_to = url_from(params[:return_to]) || default_return_to
  end

  def default_return_to
    @source.is_a?(CouponEvent) ? coupon_events_path : compliment_events_path
  end

  def source_notes
    StudentActivityNote.where(source: @source).includes(:author).order(:created_at, :id)
  end

  def respond_with_panel(notice)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          dom_id(@source, :activity_notes),
          partial: "student_activity_notes/panel",
          locals: {
            source: @source,
            notes: source_notes,
            current_user: current_user,
            return_to: @return_to
          }
        )
      end
      format.html { redirect_to @return_to, notice: notice, status: :see_other }
    end
  end

  def render_not_found
    skip_authorization
    head :not_found
  end
end
