class UseCaseInsensitiveCouponTemplateTitleIndex < ActiveRecord::Migration[7.1]
  OLD_INDEX_NAME = "idx_coupon_templates_owner_bucket_title_uniqueness"
  NEW_INDEX_NAME = "idx_coupon_templates_owner_bucket_lower_title_uniqueness"

  def up
    duplicate_rows = select_all(<<~SQL.squish)
      SELECT created_by_id, bucket, LOWER(title) AS normalized_title, COUNT(*) AS count
      FROM coupon_templates
      GROUP BY created_by_id, bucket, LOWER(title)
      HAVING COUNT(*) > 1
    SQL

    if duplicate_rows.any?
      examples = duplicate_rows.first(5).map do |row|
        "created_by_id=#{row['created_by_id']}, bucket=#{row['bucket']}, title=#{row['normalized_title']}, count=#{row['count']}"
      end.join("; ")

      raise ActiveRecord::MigrationError,
            "Case-insensitive duplicate coupon template titles must be resolved before adding #{NEW_INDEX_NAME}: #{examples}"
    end

    remove_index :coupon_templates, name: OLD_INDEX_NAME
    add_index :coupon_templates,
              "created_by_id, bucket, LOWER(title)",
              unique: true,
              name: NEW_INDEX_NAME
  end

  def down
    remove_index :coupon_templates, name: NEW_INDEX_NAME
    add_index :coupon_templates,
              %i[created_by_id bucket title],
              unique: true,
              name: OLD_INDEX_NAME
  end
end
