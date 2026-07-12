class CreateSchoolClosures < ActiveRecord::Migration[7.1]
  def change
    create_table :school_closures do |t|
      t.references :school, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false

      t.timestamps

      t.index %i[school_id starts_on ends_on]
    end
  end
end
