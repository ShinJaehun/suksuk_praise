class AddDefaultImageKeyToCouponTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :coupon_templates, :default_image_key, :string
  end
end
