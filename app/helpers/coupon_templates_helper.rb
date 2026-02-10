module CouponTemplatesHelper
  def coupon_thumbnail(tpl)
    klass = 'w-10 h-10 rounded object-cover border bg-white shrink-0'

    if tpl.image.attached?
      # active storage
      image_tag(tpl.image, class: klass)
    elsif tpl.default_image_key.present?
      image_tag(tpl.default_image_key, class: klass)
    else
      content_tag :div, '', class: 'w-10 h-10 rounded border bg-gray-100 shrink-0'
    end
  end
end
