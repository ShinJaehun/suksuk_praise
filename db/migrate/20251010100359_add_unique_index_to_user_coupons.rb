class AddUniqueIndexToUserCoupons < ActiveRecord::Migration[7.1]
  def change
    add_index :user_coupons,
          [:user_id, :classroom_id, :issuance_basis, :period_start_on],
          unique: true,
          where: "status = 0",
          name: "index_user_coupons_on_user_and_period_unique"
  end
end
