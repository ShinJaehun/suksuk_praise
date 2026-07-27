class CreateStudentActivityNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :student_activity_notes do |t|
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :classroom, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :source, polymorphic: true, null: false, index: false
      t.text :body, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :student_activity_notes,
      %i[source_type source_id author_id],
      unique: true,
      name: "idx_activity_notes_source_author"
    add_index :student_activity_notes,
      %i[student_id occurred_at],
      name: "idx_activity_notes_student_occurred"
  end
end
