class AddStudentLoginTokenToClassrooms < ActiveRecord::Migration[7.1]
  class MigrationClassroom < ApplicationRecord
    self.table_name = "classrooms"
  end

  TOKEN_LENGTH = 24

  def up
    add_column :classrooms, :student_login_token, :string

    say_with_time "Backfilling classroom student login tokens" do
      used_tokens = {}

      MigrationClassroom.reset_column_information
      MigrationClassroom.find_each do |classroom|
        token = generate_unique_token(used_tokens)
        used_tokens[token] = true

        classroom.update_columns(student_login_token: token)
      end
    end

    change_column_null :classrooms, :student_login_token, false
    add_index :classrooms, :student_login_token, unique: true
  end

  def down
    remove_index :classrooms, :student_login_token
    remove_column :classrooms, :student_login_token
  end

  private

  def generate_unique_token(used_tokens)
    loop do
      token = SecureRandom.base58(TOKEN_LENGTH)
      return token unless used_tokens[token] || MigrationClassroom.exists?(student_login_token: token)
    end
  end
end
