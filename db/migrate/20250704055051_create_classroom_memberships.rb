class CreateClassroomMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :classroom_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end
  end
end
