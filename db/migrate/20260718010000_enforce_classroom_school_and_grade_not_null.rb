class EnforceClassroomSchoolAndGradeNotNull < ActiveRecord::Migration[7.1]
  def up
    missing_classroom_ids = connection.select_values(<<~SQL.squish)
      SELECT id
      FROM classrooms
      WHERE school_id IS NULL
         OR grade IS NULL
      ORDER BY id
      LIMIT 20
    SQL
    missing_classroom_count = connection.select_value(<<~SQL.squish).to_i
      SELECT COUNT(*)
      FROM classrooms
      WHERE school_id IS NULL
         OR grade IS NULL
    SQL

    if missing_classroom_count.positive?
      missing_school_count = connection.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*)
        FROM classrooms
        WHERE school_id IS NULL
      SQL
      missing_grade_count = connection.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*)
        FROM classrooms
        WHERE grade IS NULL
      SQL

      raise ActiveRecord::MigrationError,
        "Cannot enforce classroom school/grade constraints: " \
        "#{missing_classroom_count} classrooms have missing required values " \
        "(missing school: #{missing_school_count}, missing grade: #{missing_grade_count}; " \
        "classroom IDs, up to 20: #{missing_classroom_ids.join(', ')}). " \
        "Resolve the data before retrying."
    end

    change_column_null :classrooms, :school_id, false
    change_column_null :classrooms, :grade, false
  end

  def down
    change_column_null :classrooms, :school_id, true
    change_column_null :classrooms, :grade, true
  end
end
