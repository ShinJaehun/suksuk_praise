module UsersHelper
  def display_name(user)
    user.name.present? ? user.name : "이름 없음"
  end

  def user_avatar_path(user, size:)
    index = user.default_avatar_index.to_i
    index = 1 unless index.between?(1, 32)
    "avatars/user_profile_#{format('%02d', index)}_#{size}.png"
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
