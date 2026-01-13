module CouponDraw
  class Issue
    class NoCandidateError < StandardError; end
    class DuplicatePeriodError < StandardError; end
    class NoActiveTemplateError < StandardError; end
    class NotComplimentKingToday < StandardError; end

    # 반환: UserCoupon
    def self.call(classroom:, basis:, mode:, issued_by:, target_user_id: nil)
      now = Time.zone.now

      basis = normalize_basis(basis)
      mode  = normalize_mode(basis, mode)

      # 1) 대상(버튼 UX: user_id 필수) + 교실 소속 보장
      raise ArgumentError, "user_id required" if target_user_id.blank?
      user = classroom.students.find(target_user_id)

      # 2) 정책 검증: daily_top → 반드시 '오늘의 칭찬왕(동률 포함)'이어야 함
      if basis == "daily" && mode == "daily_top"
        today_range = now.beginning_of_day..now.end_of_day
        counts = Compliment.where(classroom: classroom, given_at: today_range)
                           .group(:receiver_id).count
        raise NoCandidateError, "선발할 학생이 없습니다." if counts.blank?

        max = counts.values.max
        king_ids = counts.select { |_, c| c == max }.keys
        raise NotComplimentKingToday, "오늘의 칭찬왕이 아닙니다." unless king_ids.include?(user.id)
      end

      # 3) 기간 시작 계산 & 중복 가드(daily만 1일 1회)
      period_start = UserCoupon.period_start_for(basis, now: now)
      if basis == "daily"
        if UserCoupon.period_duplicate_of(
             user_id:         user.id,
             classroom_id:    classroom.id,
             basis:           basis,
             basis_tag:       mode,
             period_start_on: period_start
           ).exists?
          raise DuplicatePeriodError, "이미 오늘 발급되었습니다."
        end
      end

      # 4) 템플릿 가중 랜덤 (P2.5 개인 스코프)
      # -> 교사(issued_by) 소유 + 활성 템플릿만 후보로 사용
      personal_scope = CouponTemplate.where(created_by_id: issued_by.id, bucket: "personal", active: true)
      template = weighted_pick_from_scope(personal_scope)
      raise NoActiveTemplateError, "활성 쿠폰 템플릿이 없습니다." unless template

      # 5) 발급
      UserCoupon.issue!(
        user:             user,
        classroom:        classroom,
        template:         template,
        issued_by:        issued_by,
        issuance_basis:   basis,
        period_start_on:  period_start,
        basis_tag:        mode
      )
    end

    # --- helpers ---

    def self.normalize_basis(basis)
      b = basis.to_s.strip
      case b
      when "manual" then "manual"
      else "daily" # 현재는 daily/manual만 운영
      end
    end

    def self.normalize_mode(basis, mode)
      m = mode.to_s.strip
      return m if m.present?
      basis == "manual" ? "default" : "daily_top"
    end

    # 주어진 스코프에서 weight 기반 가중 랜덤 선택
    def self.weighted_pick_from_scope(scope)
      # 안전장치: DB 집계 1회, N+1 방지 위해 id/weight만 우선 읽고, 필요 시 1건만 다시 로드
      rows = scope.select(:id, :weight).load
      return nil if rows.empty?

      total = rows.sum(&:weight).to_i
      return nil if total <= 0

      pivot = rand(total)
      acc = 0
      picked_id = nil

      rows.each do |r|
        acc += r.weight.to_i
        if pivot < acc
          picked_id = r.id
          break
        end
      end

      # 최종 한 건만 전체 컬럼으로 로드
      scope.find_by(id: picked_id)
    end
  end
end