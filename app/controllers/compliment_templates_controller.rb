class ComplimentTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_compliment_preset, only: %i[edit update destroy]

  def index
    authorize ComplimentPreset

    @compliment_presets = policy_scope(ComplimentPreset).active.ordered
    @compliment_preset = current_user.compliment_presets.new(active: true)
  end

  def create
    authorize ComplimentPreset

    current_user.with_lock do
      @compliment_preset = current_user.compliment_presets.new(compliment_preset_params.merge(active: true))

      if current_user.compliment_presets.active.count >= ComplimentPreset::MAX_ACTIVE_PER_USER
        @compliment_preset.errors.add(:base, :too_many_active_presets)
      elsif @compliment_preset.save
        redirect_to compliment_templates_path,
          notice: t("compliment_presets.flash.created"),
          status: :see_other
        return
      end
    end

    @compliment_presets = policy_scope(ComplimentPreset).active.ordered
    render :index, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    @compliment_preset.errors.add(:title, :taken)
    @compliment_presets = policy_scope(ComplimentPreset).active.ordered
    render :index, status: :unprocessable_entity
  end

  def edit
  end

  def update
    if @compliment_preset.update(compliment_preset_params)
      redirect_to compliment_templates_path,
        notice: t("compliment_presets.flash.updated"),
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @compliment_preset.errors.add(:title, :taken)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @compliment_preset.update!(active: false)

    redirect_to compliment_templates_path,
      notice: t("compliment_presets.flash.destroyed"),
      status: :see_other
  end

  private

  def set_compliment_preset
    @compliment_preset = policy_scope(ComplimentPreset).find(params[:id])
    authorize @compliment_preset
  end

  def compliment_preset_params
    params.require(:compliment_preset).permit(:title)
  end
end
