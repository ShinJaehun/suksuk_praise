class Admin::SchoolsController < Admin::BaseController
  before_action :set_school, only: %i[edit update]
  layout -> { turbo_frame_request? ? false : "application" }

  def new
    @school = School.new
    authorize @school
  end

  def create
    @school = School.new(school_params)
    authorize @school

    if @school.save
      respond_with_success(t("admin.schools.create.success"))
    else
      render_school_form(:new)
    end
  end

  def edit
    authorize @school
  end

  def update
    authorize @school

    if @school.update(school_params)
      respond_with_success(t("admin.schools.update.success"))
    else
      render_school_form(:edit)
    end
  end

  private

  def set_school
    @school = School.find(params[:id])
  end

  def school_params
    params.require(:school).permit(:name)
  end

  def respond_with_success(message)
    if turbo_frame_request?
      flash[:notice] = message
      render turbo_stream: turbo_stream.refresh
    else
      redirect_to classrooms_path, notice: message
    end
  end

  def render_school_form(template)
    render template, formats: :html, status: :unprocessable_entity
  end
end
