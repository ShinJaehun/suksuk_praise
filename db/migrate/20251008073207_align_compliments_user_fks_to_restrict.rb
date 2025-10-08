class AlignComplimentsUserFksToRestrict < ActiveRecord::Migration[7.1]
  def up
    # 기존 FK 드롭 (현재는 ON DELETE SET NULL)
    remove_foreign_key :compliments, column: :giver_id
    remove_foreign_key :compliments, column: :receiver_id

    # RESTRICT(기본)로 재생성
    # on_delete 옵션을 생략하면 DB 기본(RESTRICT/NO ACTION)로 동작합니다.
    add_foreign_key :compliments, :users, column: :giver_id
    add_foreign_key :compliments, :users, column: :receiver_id
  end

  def down
    # 되돌리기: 다시 NULLIFY로 복원
    remove_foreign_key :compliments, column: :giver_id
    remove_foreign_key :compliments, column: :receiver_id

    add_foreign_key :compliments, :users, column: :giver_id,    on_delete: :nullify
    add_foreign_key :compliments, :users, column: :receiver_id, on_delete: :nullify
  end
end
