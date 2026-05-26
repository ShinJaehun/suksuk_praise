class AddMessagePolicyToClassrooms < ActiveRecord::Migration[7.1]
  def up
    add_column :classrooms, :message_policy, :string, default: "replies_only", null: false

    execute <<~SQL.squish
      UPDATE classrooms
      SET message_policy = CASE
        WHEN student_initiated_messages_enabled = TRUE THEN 'student_initiated'
        ELSE 'replies_only'
      END
    SQL
  end

  def down
    remove_column :classrooms, :message_policy
  end
end
