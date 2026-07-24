class MigrateComplimentPresetsFromClassroomToUser < ActiveRecord::Migration[7.1]
  OLD_POSITION_INDEX = "idx_compliment_presets_classroom_active_position"
  OLD_TITLE_INDEX = "idx_compliment_presets_active_title_uniqueness"
  OLD_CLASSROOM_INDEX = "index_compliment_presets_on_classroom_id"
  NEW_POSITION_INDEX = "idx_compliment_presets_user_active_position"
  NEW_TITLE_INDEX = "idx_compliment_presets_active_user_title"

  def up
    return unless table_exists?(:compliment_presets)

    has_classroom_id = column_exists?(:compliment_presets, :classroom_id)
    has_user_id = column_exists?(:compliment_presets, :user_id)

    if has_classroom_id && !has_user_id
      migrate_old_classroom_owned_presets!
    elsif has_user_id && !has_classroom_id
      ensure_user_indexes!
    else
      raise ActiveRecord::MigrationError,
        "Unexpected compliment_presets ownership columns: classroom_id=#{has_classroom_id}, user_id=#{has_user_id}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_old_classroom_owned_presets!
    nullify_existing_compliment_preset_references!
    execute "DELETE FROM compliment_presets"

    remove_index_by_name(OLD_TITLE_INDEX)
    remove_index_by_name(OLD_POSITION_INDEX)
    remove_index_by_name(OLD_CLASSROOM_INDEX)

    if foreign_key_exists?(:compliment_presets, :classrooms, column: :classroom_id)
      remove_foreign_key :compliment_presets, column: :classroom_id
    end

    remove_column :compliment_presets, :classroom_id
    add_reference :compliment_presets, :user, null: false, foreign_key: true

    ensure_user_indexes!
  end

  def nullify_existing_compliment_preset_references!
    return unless table_exists?(:compliments)
    return unless column_exists?(:compliments, :compliment_preset_id)

    execute "UPDATE compliments SET compliment_preset_id = NULL WHERE compliment_preset_id IS NOT NULL"
  end

  def ensure_user_indexes!
    remove_index_by_name(OLD_TITLE_INDEX)

    unless index_name_exists?(:compliment_presets, NEW_POSITION_INDEX)
      add_index :compliment_presets, %i[user_id active position id],
        name: NEW_POSITION_INDEX
    end

    return if index_name_exists?(:compliment_presets, NEW_TITLE_INDEX)

    add_index :compliment_presets, "user_id, lower(title)",
      unique: true,
      where: "active = TRUE",
      name: NEW_TITLE_INDEX
  end

  def remove_index_by_name(name)
    return unless index_name_exists?(:compliment_presets, name)

    remove_index :compliment_presets, name: name
  end
end
