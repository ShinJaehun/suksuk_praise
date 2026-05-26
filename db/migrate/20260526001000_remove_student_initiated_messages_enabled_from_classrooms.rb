class RemoveStudentInitiatedMessagesEnabledFromClassrooms < ActiveRecord::Migration[7.1]
  def up
    remove_column :classrooms, :student_initiated_messages_enabled
  end

  def down
    add_column :classrooms, :student_initiated_messages_enabled, :boolean, default: false, null: false
  end
end
