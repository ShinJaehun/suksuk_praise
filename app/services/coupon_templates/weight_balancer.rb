module CouponTemplates
  class WeightBalancer
    TOTAL = 100
    UNIT  = 10  # 🔸 십의 자리로 고정

    def self.normalize!(user)
      CouponTemplate.transaction do
        all = CouponTemplate.lock.where(created_by_id: user.id, bucket: "personal").order(:id)
        actives = all.select(&:active)
        inactives = all.reject(&:active)
        inactives.each { |tpl| tpl.update_columns(weight: 0) unless tpl.weight.to_i == 0 }
        return if actives.empty?

        weights = actives.map { _1.weight.to_i }
        sum = weights.sum

        strategy =
          case strategy
          when :equal, :proportional then strategy
          else # :auto (기존 규칙)
            (sum == 0 || weights.any?(&:zero?)) ? :equal : :proportional
          end

        new_weights =
          if strategy == :equal
            equal_split_units_then_scale(actives.size, TOTAL, UNIT)
          else
            proportional_split_units_then_scale(weights, TOTAL, UNIT)
          end

        actives.zip(new_weights).each { |tpl, w| tpl.update_columns(weight: w) if tpl.weight.to_i != w }
      end
    end
  end
end