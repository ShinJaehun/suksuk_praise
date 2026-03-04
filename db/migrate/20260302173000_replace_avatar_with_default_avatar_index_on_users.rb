class ReplaceAvatarWithDefaultAvatarIndexOnUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :default_avatar_index, :integer
    remove_column :users, :avatar, :string
  end
end
