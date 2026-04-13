module ClassroomsHelper
  def compliment_king_frame_id(classroom, period)
    dom_id(classroom, :"compliment_king_#{period}")
  end

  def compliment_king_board_classes(period_count)
    base = "grid gap-4"
    columns =
      case period_count
      when 1 then "lg:grid-cols-1"
      when 2 then "lg:grid-cols-2"
      else "lg:grid-cols-3"
      end

    [base, columns].join(" ")
  end

  def compliment_king_card_classes(section)
    return "h-full rounded-2xl border border-slate-200 bg-white p-5 shadow-sm" unless compliment_king_populated?(section)

    "h-full rounded-2xl border border-amber-200 bg-amber-50 p-5 shadow-sm"
  end

  def compliment_king_title_classes(section)
    return "text-lg font-extrabold text-slate-900" unless compliment_king_populated?(section)

    "text-lg font-extrabold text-amber-900"
  end

  def compliment_king_count_classes(section)
    return "mt-1 text-sm text-amber-800" if compliment_king_populated?(section)

    "mt-3 text-sm text-slate-500"
  end

  def compliment_king_populated?(section)
    section.present? && section.winners.present? && section.compliment_count.to_i.positive?
  end

  def compliment_king_empty_message(period)
    t("empty.compliment_king.#{period}")
  end

  def show_compliment_king_coupon_button?(classroom, period)
    %w[daily weekly monthly].include?(period) && policy(classroom).draw_coupon?
  end

  def compliment_king_coupon_basis(period)
    period
  end

  def compliment_king_coupon_mode(period)
    "#{period}_top"
  end

  def compliment_king_coupon_issued?(issued_winner_ids, user)
    issued_winner_ids.include?(user.id)
  end

  def compliment_king_coupon_button_classes(disabled:)
    base = "rounded-md px-3 py-1.5 text-sm font-semibold sm:ml-auto"
    tone =
      if disabled
        "cursor-not-allowed bg-slate-200 text-slate-500"
      else
        "bg-amber-400 text-amber-950 hover:bg-amber-500"
      end

    [base, tone].join(" ")
  end

  def compliment_king_issued_badge
    content_tag(
      :span,
      "발급됨",
      class: "inline-block rounded-full bg-slate-900 px-2 py-0.5 text-[11px] font-bold text-white"
    )
  end
end
