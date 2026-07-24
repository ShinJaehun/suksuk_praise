class CreateComplimentPresets < ActiveRecord::Migration[7.1]
  def change
    create_table :compliment_presets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :position, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :compliment_presets, [:user_id, :active, :position, :id],
      name: "idx_compliment_presets_user_active_position"
    add_index :compliment_presets, "user_id, lower(title)",
      unique: true,
      where: "active = TRUE",
      name: "idx_compliment_presets_active_user_title"
  end
end
