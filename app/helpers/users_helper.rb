module UsersHelper
  def display_name(user)
    user.name.present? ? user.name : "이름 없음"
  end
end