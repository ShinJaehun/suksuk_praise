class CreateCouponTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :coupon_templates do |t|
      t.string :title, null: false
      t.integer :weight, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :coupon_templates, :active
    add_index :coupon_templates, :title, unique: true
  end
end
