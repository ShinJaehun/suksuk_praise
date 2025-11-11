module CouponTemplates
  class AutoAdopter
    # 교사 계정 생성 시, 라이브러리 쿠폰을 기반으로
    # personal 쿠폰 세트를 초기 생성한다.
    #
    # - teacher 가 아니면 noop
    # - 이미 가진 title 은 건너뜀 (idempotent)
    # - 생성된 personal 은 inactive/weight=0 에서 시작
    # - 마지막에 WeightBalancer.normalize!(teacher) 호출
    #
    def self.setup_for_teacher!(teacher)
      return unless teacher&.teacher?

      CouponTemplate.transaction do
        library_candidates = CouponTemplate
          .library_onboarding_candidates
          .lock
          .to_a

        return if library_candidates.empty?

        # 이미 가진 personal(title 기준, case-insensitive)
        existing_titles = CouponTemplate
          .where(
            bucket: "personal",
            created_by_id: teacher.id,
            title: library_candidates.map(&:title)
          )
          .pluck(:title)
          .map(&:downcase)
          .to_set

        library_candidates.each do |tpl|
          title_downcased = tpl.title.to_s.downcase
          next if existing_titles.include?(title_downcased)

          CouponTemplate.create!(
            bucket:      "personal",
            created_by:  teacher,
            title:       tpl.title,
            active:      false, # 비활성 + weight=0 → 현재 불변식과 일관
            weight:      0
          )
        end

        # 새로 생성한 personal 세트를 기준으로 가중치 정규화
        CouponTemplates::WeightBalancer.normalize!(teacher)
      end
    end
  end
end