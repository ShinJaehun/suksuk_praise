class ChangeCouponTemplatesSourceTemplateFkOnDelete < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :coupon_templates, column: :source_template_id

    add_foreign_key :coupon_templates, :coupon_templates,
                    column: :source_template_id,
                    on_delete: :nullify
  end
end
