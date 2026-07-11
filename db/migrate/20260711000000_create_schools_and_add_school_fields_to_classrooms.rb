class CreateSchoolsAndAddSchoolFieldsToClassrooms < ActiveRecord::Migration[7.1]
  def change
    create_table :schools do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_reference :classrooms, :school, foreign_key: true, index: true
    add_column :classrooms, :grade, :integer
  end
end
