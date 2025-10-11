class AddComplimentDuplicateGuardIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :compliments,
              [:classroom_id, :giver_id, :receiver_id, :given_at],
              name: "idx_compliments_dup_guard"
  end
end
