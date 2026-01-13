# app/services/coupon_templates/weight_balancer.rb
module CouponTemplates
  class WeightBalancer
    TOTAL = 100
    UNIT  = 10  # 🔸 십의 자리로 고정(개인 버킷 기준)

    # === 1) 개인 버킷(현재 사용자) 세트 정규화 ===
    #
    # - 대상: bucket=personal AND created_by_id=user
    # - 규칙:
    #   - inactive는 weight=0으로 보정
    #   - active가 0개면 noop
    #   - active가 1개면 100 몰빵
    #   - active가 여러 개:
    #       * 전체합이 0이거나 0이 섞여 있으면 균등 분배(equal_split_units)
    #       * 아니면 기존 비율대로 비례 분배(proportional_split_units)
    #   - 항상 UNIT(10) 단위로 맞춤
    #
    def self.normalize!(user)
      CouponTemplate.transaction do
        all = CouponTemplate.lock
                            .where(created_by_id: user.id, bucket: "personal")
                            .order(:id)
                            .to_a

        actives   = all.select(&:active)
        inactives = all - actives

        # 비활성은 항상 0으로 고정(모델 훅과 중복이지만 방어용 보정)
        inactives.each do |tpl|
          w = tpl.weight.to_i
          tpl.update_columns(weight: 0) unless w == 0
        end

        return if actives.empty?
        return actives.first.update_columns(weight: TOTAL) if actives.size == 1

        current = actives.map { _1.weight.to_i }
        sum     = current.sum

        # 전체합 0이거나 0 포함 → 균등, 그 외 → 비례
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

    # === 2) 라이브러리(관리자용) 정규화 ===
    #
    # - 대상: bucket=library AND active=true 전체
    # - 의도:
    #   - “기본 추천 세트” 비율을 깔끔하게 관리자가 한 번에 정리
    #   - inactive는 손대지 않음 (히스토리/임시 보관용으로 남길 수 있게)
    #   - active가 1개면 100 몰빵
    #   - active가 여러 개면 UNIT(10) 단위로 균등 분배
    #
    def self.normalize_library!
      CouponTemplate.transaction do

        # 안전장치: weight<=0 인데 active=true로 남아있는 항목이 있으면 꺼버린다.
        # (모델 훅과 중복일 수 있으나, update_columns로 우회된 케이스 방어)
        bad = CouponTemplate.lock.where(bucket: "library", active: true).where("weight <= 0").to_a
        bad.each do |tpl|
          tpl.update_columns(active: false, weight: 0)
        end

        actives = CouponTemplate.lock
                                .where(bucket: "library", active: true)
                                .order(:id)
                                .to_a

        return if actives.empty?
        return actives.first.update_columns(weight: TOTAL) if actives.size == 1

        target = equal_split_units(actives.size, TOTAL, UNIT)

        actives.zip(target).each do |tpl, w|
          tpl.update_columns(weight: w) if tpl.weight.to_i != w
        end
      end
    end

    # === helpers ===

    # n개 항목을 UNIT 단위로 균등 분배(최대잔여)
    def self.equal_split_units(n, total, unit)
      base      = (total / n / unit) * unit
      remainder = total - base * n

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
      return equal_split_units(weights.size, total, unit) if sum <= 0.0

      raw   = weights.map { |w| total * (w.to_f / sum) }
      floor = raw.map { |x| ((x / unit).floor * unit) }
      used  = floor.sum
      left  = total - used

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
