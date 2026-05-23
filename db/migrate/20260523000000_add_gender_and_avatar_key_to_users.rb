class AddGenderAndAvatarKeyToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :gender, :string
    add_column :users, :avatar_key, :string
  end
end
