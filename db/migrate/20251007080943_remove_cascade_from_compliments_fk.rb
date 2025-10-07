class RemoveCascadeFromComplimentsFk < ActiveRecord::Migration[7.1]
  def change
    # 기존 CASCADE FK 제거
    remove_foreign_key :compliments, :classrooms

    # CASCADE 없이 다시 추가 (기본: RESTRICT / NO ACTION)
    add_foreign_key :compliments, :classrooms
  end
end
