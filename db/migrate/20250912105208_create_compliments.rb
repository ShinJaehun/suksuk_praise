class CreateCompliments < ActiveRecord::Migration[7.1]
  def change
    create_table :compliments do |t|
      t.bigint :giver_id, null: true
      t.bigint :receiver_id, null: true
      t.references :classroom, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :given_at, null: false

      t.timestamps
    end

    add_index :compliments, :giver_id
    add_index :compliments, :receiver_id
    add_index :compliments, [:classroom_id, :given_at]

    add_foreign_key :compliments, :users, column: :giver_id, on_delete: :nullify
    add_foreign_key :compliments, :users, column: :receiver_id, on_delete: :nullify
  end
end
