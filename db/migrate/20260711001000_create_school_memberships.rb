class CreateSchoolMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :school_memberships do |t|
      t.references :school, null: false, foreign_key: true
      t.references :user,
        null: false,
        foreign_key: { on_delete: :cascade },
        index: { unique: true }

      t.timestamps
    end
  end
end
