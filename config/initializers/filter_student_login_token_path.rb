module StudentLoginTokenPathFilter
  STUDENT_LOGIN_PATH_PATTERN = %r{\A/c/[^/]+/login(?=$|\?)}.freeze

  def filtered_path
    super.sub(STUDENT_LOGIN_PATH_PATTERN, "/c/[FILTERED]/login")
  end
end

ActionDispatch::Request.prepend(StudentLoginTokenPathFilter)
