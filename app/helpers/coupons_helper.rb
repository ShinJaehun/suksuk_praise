module CouponsHelper
  def coupon_basis_badge(coupon)
    basis = coupon.issuance_basis.to_s
    label = I18n.t("coupons.basis.#{basis}", default: basis)

    color =
      case basis
      when "daily"  then "bg-blue-100 text-blue-700"
      when "weekly" then "bg-green-100 text-green-700"
      when "manual" then "bg-gray-200 text-gray-700"
      else                "bg-slate-200 text-slate-700"
      end

    content_tag(:span, label,
      class: "inline-block rounded-full px-2 py-0.5 text-[11px] #{color}",
      aria: { label: I18n.t("coupons.basis.aria_label", basis: label, default: "발급 기준: #{label}") }
    )
  end
end