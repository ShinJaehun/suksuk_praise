class AddUniqueActiveStudentMembershipIndex < ActiveRecord::Migration[7.1]
  INDEX_NAME = "index_classroom_memberships_on_one_active_student"
  INDEX_CONDITION = "role = 'student' AND status = 'active'"

  def up
    duplicate_user_ids = select_values(<<~SQL.squish)
      SELECT user_id
      FROM classroom_memberships
      WHERE #{INDEX_CONDITION}
      GROUP BY user_id
      HAVING COUNT(*) > 1
      ORDER BY user_id
    SQL

    if duplicate_user_ids.any?
      sample_user_ids = duplicate_user_ids.first(20).join(", ")
      raise ActiveRecord::MigrationError,
        "Cannot add the active student membership index: " \
        "#{duplicate_user_ids.size} users have duplicate active memberships " \
        "(user IDs: #{sample_user_ids}). Resolve them before retrying."
    end

    add_index :classroom_memberships,
      :user_id,
      unique: true,
      where: INDEX_CONDITION,
      name: INDEX_NAME
  end

  def down
    remove_index :classroom_memberships, name: INDEX_NAME
  end
end
