class Admin::SchoolsController < Admin::BaseController
  include SchoolWorkspacePrepareable

  before_action :set_school, only: %i[edit update deactivate reactivate]
  layout -> { turbo_frame_request? ? false : "application" }

  def new
    @school = School.new
    authorize @school
  end

  def create
    @school = School.new(school_params)
    authorize @school

    if @school.save
      redirect_to schools_path,
        notice: t("admin.schools.create.success"),
        status: :see_other
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
      redirect_to schools_path,
        notice: t("admin.schools.update.success"),
        status: :see_other
    else
      render_school_form(:edit)
    end
  end

  def deactivate
    authorize @school, :deactivate?
    update_school_status(false)
  end

  def reactivate
    authorize @school, :reactivate?
    update_school_status(true)
  end

  private

  def set_school
    @school = School.find(params[:id])
  end

  def school_params
    params.require(:school).permit(:name)
  end

  def update_school_status(active)
    if @school.update(active: active)
      redirect_to edit_school_path(@school),
        notice: t(active ? "school_status.reactivated" : "school_status.deactivated"),
        status: :see_other
    else
      @school.errors.add(:base, t("school_status.failure")) if @school.errors.empty?
      prepare_school_settings
      render "schools/edit", formats: :html, status: :unprocessable_content
    end
  end

  def render_school_form(template)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "modal",
          partial: "admin/schools/modal",
          locals: modal_locals(template)
        ), status: :unprocessable_content
      end
      format.html do
        render template, formats: :html, status: :unprocessable_content
      end
    end
  end

  def modal_locals(template)
    if template == :new
      { school: @school, title: t("admin.schools.new_title"), submit_label: t("admin.schools.form.create_submit") }
    else
      { school: @school, title: t("admin.schools.edit_title"), submit_label: t("admin.schools.form.update_submit") }
    end
  end
end
