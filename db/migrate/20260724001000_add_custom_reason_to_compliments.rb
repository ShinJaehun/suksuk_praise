class AddCustomReasonToCompliments < ActiveRecord::Migration[7.1]
  def change
    add_reference :compliments, :compliment_preset, foreign_key: true
    add_column :compliments, :reason, :string
  end
end
