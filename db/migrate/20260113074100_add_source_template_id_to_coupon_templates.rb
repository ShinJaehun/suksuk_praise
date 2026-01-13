class AddSourceTemplateIdToCouponTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :coupon_templates, :source_template_id, :bigint
    # teacher(=created_by) 기준으로 같은 library 원본은 personal에 1개만 유지(멱등 upsert)
    add_index :coupon_templates, [:created_by_id, :source_template_id],
              unique: true,
              where: "source_template_id IS NOT NULL",
              name: "index_coupon_templates_on_creator_and_source"
    add_foreign_key :coupon_templates, :coupon_templates, column: :source_template_id
  end
end
