class AddComplimentKingPeriodSettingsToClassrooms < ActiveRecord::Migration[7.1]
  def change
    add_column :classrooms, :daily_compliment_king_enabled, :boolean, default: true, null: false
    add_column :classrooms, :weekly_compliment_king_enabled, :boolean, default: false, null: false
    add_column :classrooms, :monthly_compliment_king_enabled, :boolean, default: false, null: false
  end
end
