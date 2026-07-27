class AddActiveToSchools < ActiveRecord::Migration[7.1]
  def change
    add_column :schools, :active, :boolean, default: true, null: false
    add_index :schools, :active
  end
end
