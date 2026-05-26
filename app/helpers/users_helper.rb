module UsersHelper
  AVATAR_ASSET_DIR = Rails.root.join("app/assets/images/avatars")
  DEFAULT_AVATAR_KEY = "boy01"
  AVAILABLE_AVATAR_KEYS = Dir.children(AVATAR_ASSET_DIR)
                             .grep(/\A.+\.png\z/)
                             .map { |filename| File.basename(filename, ".png") }
                             .freeze

  def display_name(user)
    user.name.present? ? user.name : "이름 없음"
  end

  def user_avatar_path(user, size:)
    avatar_key = user.avatar_key if available_avatar_key?(user.avatar_key)
    "avatars/#{avatar_key.presence || existing_fallback_avatar_key(user)}.png"
  end

  def fallback_avatar_key(user)
    return "admin" if user.admin?
    return user.gender == "female" ? "teacherF01" : "teacherM01" if user.teacher?
    return user.gender == "girl" ? "girl01" : "boy01" if user.student?

    "boy01"
  end

  def existing_fallback_avatar_key(user)
    fallback_key = fallback_avatar_key(user)
    return fallback_key if avatar_asset_key?(fallback_key)

    available_avatar_keys.include?(DEFAULT_AVATAR_KEY) ? DEFAULT_AVATAR_KEY : available_avatar_keys.first
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

  def available_avatar_key?(avatar_key)
    User::AVATAR_KEYS.include?(avatar_key) && avatar_asset_key?(avatar_key)
  end

  def avatar_asset_key?(avatar_key)
    available_avatar_keys.include?(avatar_key)
  end

  def available_avatar_keys
    AVAILABLE_AVATAR_KEYS
  end
end
