require "base64"

class Classrooms::StudentLoginsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_classroom
  before_action :authorize_manage_members!

  def student_login_info
    @student_login_url = public_student_login_url(
      student_login_token: @classroom.student_login_token
    )

    render "classrooms/student_login_info"
  end

  def student_login_qr
    @student_login_url = public_student_login_url(
      student_login_token: @classroom.student_login_token
    )
    @student_login_qr_png_data_url = qr_png_data_url(@student_login_url)

    render "classrooms/student_login_qr"
  end

  def download_student_login_qr
    student_login_url = public_student_login_url(
      student_login_token: @classroom.student_login_token
    )
    send_data qr_png_binary(student_login_url),
      type: "image/png",
      disposition: "attachment",
      filename: "student-login-qr-#{@classroom.id}.png"
  end

  def regenerate_student_login_token
    @classroom.regenerate_student_login_token
    redirect_to classroom_path(@classroom),
      notice: "학생 로그인 주소를 재발급했습니다. 기존에 복사해 둔 주소와 기존 QR 코드는 더 이상 사용할 수 없습니다. 아래 새 주소를 다시 복사하거나 QR 코드를 다시 안내하세요.",
      status: :see_other
  end

  private

  def set_classroom
    @classroom = Classroom.find(params[:id])
  end

  def authorize_manage_members!
    authorize @classroom, :manage_members?
  end

  def qr_png_data_url(text)
    "data:image/png;base64,#{Base64.strict_encode64(qr_png_binary(text))}"
  end

  def qr_png_binary(text)
    RQRCode::QRCode.new(text).as_png(size: 320).to_s
  end
end
