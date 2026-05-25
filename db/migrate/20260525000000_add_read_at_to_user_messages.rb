class AddReadAtToUserMessages < ActiveRecord::Migration[7.1]
  def up
    add_column :user_messages, :read_at, :datetime
    add_index :user_messages, [:classroom_id, :sender_id, :read_at],
      name: "idx_user_messages_classroom_sender_read_at"

    now = Time.current
    execute sanitize_sql_array(["UPDATE user_messages SET read_at = ? WHERE read_at IS NULL", now])
  end

  def down
    remove_index :user_messages, name: "idx_user_messages_classroom_sender_read_at"
    remove_column :user_messages, :read_at
  end

  private

  def sanitize_sql_array(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end
