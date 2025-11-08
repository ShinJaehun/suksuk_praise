class CreateCouponTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :coupon_templates do |t|
      t.string :title, null: false
      t.integer :weight, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :bucket, null: false, default: "personal"

      t.timestamps
    end

    # ▼ 인덱스들
    add_index :coupon_templates, :active
    
    # owener + bucket + title 고유 제약조건
    add_index :coupon_templates, [:created_by_id, :bucket, :title],
              unique: true,
              name: "idx_coupon_templates_owner_bucket_title_uniqueness"

    add_index :coupon_templates, [:created_by_id, :bucket],
              name: "index_coupon_templates_on_created_by_and_bucket"
  end
end
