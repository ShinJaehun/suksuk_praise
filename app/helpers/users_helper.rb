module UsersHelper
  def display_name(user)
    user.name.present? ? user.name : "이름 없음"
  end

  def user_avatar_path(user, size:)
    avatar_key = user.avatar_key if User::AVATAR_KEYS.include?(user.avatar_key)
    "avatars/#{avatar_key.presence || fallback_avatar_key(user)}.png"
  end

  def fallback_avatar_key(user)
    return "admin" if user.admin?
    return user.gender == "female" ? "teacherF01" : "teacherM01" if user.teacher?
    return user.gender == "girl" ? "girl01" : "boy01" if user.student?

    "boy01"
  end

  def user_avatar_image(user, size:, **options)
    if user.avatar.attached?
      return image_tag(
        user.avatar.variant(resize_to_limit: [ size, size ]),
        **options
      )
    end

    image_tag(user_avatar_path(user, size: size), **options)
  end
end
