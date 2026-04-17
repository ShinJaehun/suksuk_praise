class AddParentMessageToUserMessages < ActiveRecord::Migration[7.1]
  def change
    add_reference :user_messages, :parent_message, foreign_key: { to_table: :user_messages }, null: true
    add_index :user_messages, [:parent_message_id, :created_at]
  end
end
