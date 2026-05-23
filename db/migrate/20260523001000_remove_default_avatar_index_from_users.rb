class RemoveDefaultAvatarIndexFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :default_avatar_index, :integer
  end
end
