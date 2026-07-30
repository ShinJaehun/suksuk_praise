class AddStudentNumberToClassroomMemberships < ActiveRecord::Migration[7.1]
  INDEX_NAME = "idx_classroom_memberships_active_student_number"
  INDEX_CONDITION = <<~SQL.squish
    role = 'student' AND
    status = 'active' AND
    student_number IS NOT NULL
  SQL
  CHECK_NAME = "chk_classroom_memberships_student_number_positive"

  def change
    add_column :classroom_memberships, :student_number, :integer, null: true
    add_check_constraint :classroom_memberships,
      "student_number IS NULL OR student_number > 0",
      name: CHECK_NAME
    add_index :classroom_memberships,
      [:classroom_id, :student_number],
      unique: true,
      where: INDEX_CONDITION,
      name: INDEX_NAME
  end
end
