module CouponTemplates
  class WeightBalancer
    TOTAL = 100
    UNIT  = 10  # 🔸 십의 자리로 고정

    # 개인 버킷(현재 사용자) 세트만 정규화
    def self.normalize!(user)
      CouponTemplate.transaction do
        all = CouponTemplate.lock.where(created_by_id: user.id, bucket: "personal").order(:id).to_a
        actives   = all.select(&:active)
        inactives = all - actives

        # 비활성은 항상 0으로 고정(모델 훅과 중복이지만 여기서도 보정)
        inactives.each do |tpl|
          w = tpl.weight.to_i
          tpl.update_columns(weight: 0) unless w == 0
        end

        return if actives.empty?
        return actives.first.update_columns(weight: TOTAL) if actives.size == 1

        current = actives.map { _1.weight.to_i }
        sum     = current.sum

        # 자동 전략: 전체합 0이거나 0이 포함되어 있으면 균등, 아니면 비례
        use_equal = (sum == 0 || current.any?(&:zero?))

        target =
          if use_equal
            equal_split_units(actives.size, TOTAL, UNIT)
          else
            proportional_split_units(current, TOTAL, UNIT)
          end

        actives.zip(target).each do |tpl, w|
          tpl.update_columns(weight: w) if tpl.weight.to_i != w
        end
      end
    end

    # n개 항목을 UNIT 단위로 균등 분배(최대잔여)
    def self.equal_split_units(n, total, unit)
      base      = (total / n / unit) * unit
      remainder = total - base * n
      # remainder를 UNIT씩 앞에서부터 분배
      arr = Array.new(n, base)
      i = 0
      while remainder > 0
        arr[i] += unit
        remainder -= unit
        i = (i + 1) % n
      end
      arr
    end

    # 현재 비중에 비례하여 UNIT 단위로 분배(최대잔여)
    def self.proportional_split_units(weights, total, unit)
      sum = weights.sum.to_f
      # 이상치 방어
      return equal_split_units(weights.size, total, unit) if sum <= 0.0

      raw   = weights.map { |w| total * (w.to_f / sum) }
      floor = raw.map { |x| ((x / unit).floor * unit) }
      used  = floor.sum
      left  = total - used

      # 소수부 큰 순서대로 remainder를 UNIT씩 배분
      remainders = raw.each_with_index.map { |x, i| [i, x - floor[i]] }
      remainders.sort_by! { |(_i, frac)| -frac }
      idx = 0
      while left > 0
        i, = remainders[idx]
        floor[i] += unit
        left -= unit
        idx = (idx + 1) % remainders.size
      end
      floor
    end   

  end
end