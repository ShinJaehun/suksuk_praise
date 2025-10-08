class AddFkUserCouponsIssuedByOnDeleteNullify < ActiveRecord::Migration[7.1]
  def up
    # 기존에 FK가 없다면 바로 추가
    add_foreign_key :user_coupons, :users,
                    column: :issued_by_id,
                    on_delete: :nullify
  end

  def down
    remove_foreign_key :user_coupons, column: :issued_by_id
  end
end
