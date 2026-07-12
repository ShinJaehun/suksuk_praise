class SchoolClosuresController < ApplicationController
  before_action :authenticate_user!
  before_action :set_school
  before_action :authorize_school_operations
  before_action :set_school_closure, only: %i[edit update destroy]

  def new
    @school_closure = @school.school_closures.new
  end

  def create
    @school_closure = @school.school_closures.new(school_closure_params)

    if @school_closure.save
      redirect_to school_path(@school), notice: t("school_closures.create.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @school_closure.update(school_closure_params)
      redirect_to school_path(@school), notice: t("school_closures.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @school_closure.destroy!
    redirect_to school_path(@school), notice: t("school_closures.destroy.success"), status: :see_other
  end

  private

  def set_school
    @school = policy_scope(School).find(params[:school_id])
  end

  def authorize_school_operations
    authorize @school, :manage_operations?
  end

  def set_school_closure
    @school_closure = @school.school_closures.find(params[:id])
  end

  def school_closure_params
    params.require(:school_closure).permit(:name, :starts_on, :ends_on)
  end
end
