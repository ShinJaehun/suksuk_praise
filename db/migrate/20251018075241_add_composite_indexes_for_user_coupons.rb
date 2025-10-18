class AddCompositeIndexesForUserCoupons < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # 유저 + 상태 + 발급시각 (최신순 목록)
    add_index :user_coupons, [:user_id, :status, :issued_at],
              order: { issued_at: :desc },
              algorithm: :concurrently,
              name: "idx_uc_user_status_issued_at_desc"

    # 유저 + 교실 + 상태 + 발급시각 (교실 컨텍스트용)
    add_index :user_coupons, [:user_id, :classroom_id, :status, :issued_at],
              order: { issued_at: :desc },
              algorithm: :concurrently,
              name: "idx_uc_user_classroom_status_issued_at_desc"

    # 최근 10개용 (교실 무관)
    add_index :user_coupons, [:user_id, :issued_at],
              order: { issued_at: :desc },
              algorithm: :concurrently,
              name: "idx_uc_user_issued_at_desc"
  end
end
