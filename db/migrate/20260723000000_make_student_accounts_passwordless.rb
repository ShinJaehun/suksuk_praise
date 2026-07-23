class MakeStudentAccountsPasswordless < ActiveRecord::Migration[7.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    change_column_default :users, :email, from: "", to: nil
    change_column_null :users, :email, true

    MigrationUser.where(role: "student").update_all(
      email: nil,
      encrypted_password: "",
      reset_password_token: nil,
      reset_password_sent_at: nil
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
