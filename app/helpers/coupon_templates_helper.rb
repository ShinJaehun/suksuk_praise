module CouponTemplatesHelper
  COUPON_THUMBNAIL_CLASS =
    'h-12 w-12 shrink-0 rounded-xl border border-slate-200 bg-white object-cover'.freeze

  def coupon_thumbnail(tpl, css_class: COUPON_THUMBNAIL_CLASS)
    source = coupon_thumbnail_source(tpl)
    return image_tag(source, class: css_class) if source

    coupon_thumbnail_placeholder(css_class: css_class)
  end

  def coupon_thumbnail_source(tpl)
    own_attachment = persisted_coupon_image_attachment(tpl)
    return url_for(own_attachment) if own_attachment
    return asset_path(tpl.default_image_key) if coupon_default_image_asset?(tpl.default_image_key)
    return asset_path(CouponTemplate::DEFAULT_IMAGE_KEY) if coupon_default_image_asset?(CouponTemplate::DEFAULT_IMAGE_KEY)

    nil
  end

  def coupon_thumbnail_placeholder(css_class: COUPON_THUMBNAIL_CLASS)
    content_tag :div, '', class: "#{css_class} bg-slate-100"
  end

  def coupon_default_image_asset?(default_image_key)
    default_image_key.present? &&
      Rails.root.join("app/assets/images", default_image_key).file?
  end

  private

  def persisted_coupon_image_attachment(tpl)
    return unless tpl

    attachment = tpl.image_attachment
    attachment if attachment&.persisted?
  end
end
