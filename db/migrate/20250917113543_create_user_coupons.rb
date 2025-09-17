class CreateUserCoupons < ActiveRecord::Migration[7.1]
  def change
    create_table :user_coupons do |t|
      t.references :user, null: false, foreign_key: true
      t.references :coupon_template, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :issued_at, null: false
      
      t.datetime :used_at
      t.bigint :issued_by_id

      t.timestamps
    end

    add_index :user_coupons, [:user_id, :status]
    add_index :user_coupons, :issued_by_id
    add_index :user_coupons, :issued_at
    add_index :user_coupons, :used_at
  end
end
