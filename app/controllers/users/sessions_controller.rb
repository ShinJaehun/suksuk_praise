class Users::SessionsController < Devise::SessionsController
  skip_before_action :expire_inactive_teacher_session, only: :create
  skip_before_action :expire_student_session_if_inactive, only: :create

  def create
    limiter = UserPasswordAttemptLimiter.new(
      email: params.dig(resource_name, :email),
      remote_ip: request.remote_ip
    )
    return render_throttled if limiter.blocked?

    authenticated = false
    failure_payload = catch(:warden) do
      super do |resource|
        if resource.student?
          sign_out(resource_name)
          redirect_to new_student_session_path, alert: '학생은 교실별 PIN 로그인으로 접속해 주세요.'
          return
        end

        limiter.reset
      end
      authenticated = true
    end

    return if authenticated
    return render_throttled if limiter.record_failure

    throw(:warden, failure_payload)
  end

  private

  def render_throttled
    request.env.fetch('warden').lock!
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    flash.now[:alert] = t('users.sessions.throttled')
    render :new, status: :too_many_requests
  end
end
