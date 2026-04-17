class CreateUserMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :user_messages do |t|
      t.references :classroom, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps
    end

    add_index :user_messages, [:classroom_id, :sender_id, :recipient_id, :created_at],
      name: "idx_user_messages_on_conversation"
    add_index :user_messages, [:recipient_id, :created_at]
  end
end
