module CouponsHelper
  def coupon_animation_payload(coupon)
    template = coupon.coupon_template
    image_url =
      if template.image.attached?
        url_for(template.image)
      elsif template.default_image_key.present?
        asset_path(template.default_image_key)
      end

    {
      id: dom_id(coupon),
      title: template.title,
      image_url: image_url
    }
  end

  def coupon_basis_badge(coupon)
    basis = coupon.issuance_basis.to_s
    label = I18n.t("coupons.basis.#{basis}", default: basis)

    color =
      case basis
      when "daily"   then "bg-blue-100 text-blue-700"
      when "weekly"  then "bg-green-100 text-green-700"
      when "monthly" then "bg-pink-100 text-pink-700"
      when "manual"  then "bg-gray-200 text-gray-700"
      else                "bg-slate-200 text-slate-700"
      end

    content_tag(:span, label,
      class: "inline-block rounded-full px-2 py-0.5 text-[11px] #{color}",
      aria: { label: I18n.t("coupons.basis.aria_label", basis: label, default: "발급 기준: #{label}") }
    )
  end

  def coupon_period_tag(coupon)
    label = coupon_period_tag_label(coupon)
    return unless label

    content_tag(
      :span,
      "(#{label})",
      class: "text-[11px] text-slate-500",
      aria: { label: "쿠폰 기간 정보: #{label}" }
    )
  end

  def coupon_period_tag_label(coupon)
    basis = coupon.issuance_basis.to_s
    start_on = coupon.period_start_on
    return unless start_on.present?

    case basis
    when "weekly"
      "#{start_on.month}월 #{week_of_month_monday_based(start_on)}째 주"
    when "monthly"
      "#{start_on.month}월"
    end
  end

  def week_of_month_monday_based(date)
    first_week_start = date.beginning_of_month.beginning_of_week(:monday)
    ((date.to_date - first_week_start).to_i / 7) + 1
  end
end
