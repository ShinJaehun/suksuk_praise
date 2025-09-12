class CreateClassroomMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :classroom_memberships do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :classroom, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false, default: 'student'

      t.timestamps
    end
    add_index :classroom_memberships, [:classroom_id, :user_id], unique: true

    add_check_constraint :classroom_memberships,
                      "role IN ('teacher','student')",
                      name: "chk_cm_role"
  end
end
