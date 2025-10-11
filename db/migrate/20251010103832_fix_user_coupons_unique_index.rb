class FixUserCouponsUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    # 1) 기존 인덱스 제거 (이름은 질문에서 준 이름)
    remove_index :user_coupons, name: "index_user_coupons_on_user_and_period_unique", if_exists: true

    # 2) daily + issued(=status=0) 에만 기간 유니크
    add_index :user_coupons,
      [:user_id, :classroom_id, :period_start_on],
      unique: true,
      where: "issuance_basis = 'daily' AND status = 0",
      name: "idx_user_coupons_daily_period_uniqueness"
  end
end
