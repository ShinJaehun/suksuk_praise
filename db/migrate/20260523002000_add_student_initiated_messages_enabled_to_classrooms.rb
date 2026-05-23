class AddStudentInitiatedMessagesEnabledToClassrooms < ActiveRecord::Migration[7.1]
  def change
    add_column :classrooms, :student_initiated_messages_enabled, :boolean, default: false, null: false
  end
end
