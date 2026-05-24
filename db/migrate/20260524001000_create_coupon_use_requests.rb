class CreateCouponUseRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :coupon_use_requests do |t|
      t.references :user_coupon, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.datetime :requested_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :coupon_use_requests,
      :user_coupon_id,
      unique: true,
      where: "status = 0",
      name: "idx_coupon_use_requests_pending_unique"
  end
end
