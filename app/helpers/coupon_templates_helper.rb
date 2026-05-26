module CouponTemplatesHelper
  COUPON_PLACEHOLDER_CLASS = 'w-10 h-10 rounded bg-gray-100 shrink-0'.freeze
  COUPON_THUMBNAIL_CLASS = 'w-10 h-10 rounded object-cover bg-white shrink-0'.freeze

  def coupon_thumbnail(tpl)
    if tpl.image.attached?
      image_tag(tpl.image, class: COUPON_THUMBNAIL_CLASS)
    elsif coupon_default_image_asset?(tpl.default_image_key)
      image_tag(tpl.default_image_key, class: COUPON_THUMBNAIL_CLASS)
    else
      coupon_thumbnail_placeholder
    end
  end

  def coupon_thumbnail_placeholder
    content_tag :div, '', class: COUPON_PLACEHOLDER_CLASS
  end

  def coupon_default_image_asset?(default_image_key)
    default_image_key.present? &&
      Rails.root.join("app/assets/images", default_image_key).file?
  end
end
