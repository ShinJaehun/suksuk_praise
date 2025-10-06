module CouponDraw
  class Issue
    class NoCandidateError < StandardError; end
    # class DuplicatePeriodError < StandardError; end
    class NoActiveTemplateError < StandardError; end

    # 반환: UserCoupon
    def self.call(classroom:, basis:, mode:, issued_by:, target_user_id: nil)
      now = Time.zone.now
      period_start = UserCoupon.period_start_for(basis.to_s, now: now)

      # 1) 대상 결정(수동 지정 우선, 없으면 칭찬왕 선정)
      winner =
        if target_user_id.present?
          classroom.students.find(target_user_id)
        else
          ComplimentKings::Pick.call(classroom: classroom, basis: basis, mode: mode).winner
        end
      raise NoCandidateError, "선발할 학생이 없습니다." unless winner

      # 2) 기간 중복 방지
      # if UserCoupon.for_basis_and_period(basis.to_s, period_start)
      #   .where(user_id: winner.id).exists?
      #   raise DuplicatePeriodError, "이미 해당 기간에 쿠폰을 발급받았습니다."
      # end

      # 3) 활성 템플릿 가중 랜덤
      template = CouponTemplate.weighted_pick
      raise NoActiveTemplateError, "활성 쿠폰 템플릿이 없습니다." unless template

      # 4) 발급
      UserCoupon.issue!(
        user:             winner,
        classroom:        classroom,
        template:         template,
        issued_by:        issued_by,
        issuance_basis:   basis.to_s,
        period_start_on:  period_start,
        basis_tag:        mode.to_s
      )
    end
  end
end