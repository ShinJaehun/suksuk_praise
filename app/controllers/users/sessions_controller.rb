class Users::SessionsController < Devise::SessionsController
  def create
    super do |resource|
      if resource.student?
        sign_out(resource_name)
        redirect_to new_student_session_path, alert: "학생은 교실별 PIN 로그인으로 접속해 주세요."
        return
      end
    end
  end
end
