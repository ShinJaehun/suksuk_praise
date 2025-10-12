class CreateCouponEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :coupon_events do |t|
      t.string :action, null: false
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :user_coupon, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.references :coupon_template, null: false, foreign_key: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    
    add_index :coupon_events, :action
    add_index :coupon_events, :created_at
  end
end
