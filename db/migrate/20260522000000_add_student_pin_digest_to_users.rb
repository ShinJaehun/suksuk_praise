class AddStudentPinDigestToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :student_pin_digest, :string
  end
end
