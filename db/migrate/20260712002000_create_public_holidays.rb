class CreatePublicHolidays < ActiveRecord::Migration[7.1]
  def change
    create_table :public_holidays do |t|
      t.date :date, null: false
      t.string :name, null: false
      t.string :source, null: false

      t.timestamps

      t.index %i[date name source], unique: true
    end
  end
end
