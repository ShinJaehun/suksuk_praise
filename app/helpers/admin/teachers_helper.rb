module Admin::TeachersHelper
  def teacher_classroom_label(classroom)
    grade_label = "#{classroom.grade}학년" if classroom.grade
    name = classroom.name.to_s.strip
    return name if grade_label.blank? || name.start_with?(grade_label)

    "#{grade_label} #{name}"
  end
end
