class AddColorKeyToSchools < ActiveRecord::Migration[7.1]
  COLOR_KEYS = %w[
    sky
    emerald
    violet
    amber
    rose
    teal
    indigo
    orange
  ].freeze

  class MigrationSchool < ActiveRecord::Base
    self.table_name = "schools"
  end

  def up
    add_column :schools, :color_key, :string
    MigrationSchool.reset_column_information

    MigrationSchool.order(:id).pluck(:id).each_with_index do |school_id, index|
      MigrationSchool.where(id: school_id).update_all(color_key: COLOR_KEYS[index % COLOR_KEYS.length])
    end

    change_column_null :schools, :color_key, false
  end

  def down
    remove_column :schools, :color_key
  end
end
