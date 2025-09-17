class AddIssuanceContextToUserCoupons < ActiveRecord::Migration[7.1]
  def change
    # daily/weekly/manual/hybrid
    add_column :user_coupons, :issuance_basis, :string,  null: false, default: "daily"
    
    # 기준 기간 시작일(일간=그 날짜, 주간=그 주 월요일)
    add_column :user_coupons, :period_start_on, :date,    null: false
    
    # 예: "daily_top", "weekly_top", "accumulated"
    add_column :user_coupons, :basis_tag,       :string
    
    # 조회 및 중복 방지에 유용한 인덱스들
    add_index :user_coupons, [:classroom_id, :issuance_basis, :period_start_on, :basis_tag],
              name: "idx_uc_classroom_basis_period_tag"
    add_index :user_coupons, [:user_id, :issuance_basis, :period_start_on],
              name: "idx_uc_user_basis_period"

  end
end
