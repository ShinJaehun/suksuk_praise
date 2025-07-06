class CreateCompliments < ActiveRecord::Migration[7.1]
  def change
    create_table :compliments do |t|
      t.integer :giver_id
      t.integer :receiver_id
      t.references :classroom, null: false, foreign_key: true
      t.datetime :given_at

      t.timestamps
    end
  end
end
