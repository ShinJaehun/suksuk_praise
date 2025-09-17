class UserCoupon < ApplicationRecord
  belongs_to :user
  belongs_to :coupon_template
  belongs_to :classroom

  enum status: { issued: 0, used: 1 }

  # ✅ 발급 컨텍스트 (문자열 enum)
  enum issuance_basis: {
    daily:  "daily",
    weekly: "weekly",
    manual: "manual",
    hybrid: "hybrid"
  }

  validates :issued_at, presence: true
  validates :status, presence: true
  validates :issuance_basis, presence: true
  validates :period_start_on, presence: true

  # 주간 발급/사용 같은 범위 조회가 필요할 때 쓸 수 있는 기본 스코프들
  scope :for_basis_and_period, ->(basis, period_start) {
    where(issuance_basis: basis, period_start_on: period_start)
  }

  scope :issued_this_week, lambda {
    now  = Time.zone.now
    from = now.beginning_of_week(:monday)
    to   = now.end_of_week(:monday)
    where(issued_at: from..to)
  }

  # === 기간 헬퍼 ===
  def self.period_start_for(basis, now: Time.zone.now)
    case basis.to_s
    when "weekly" then now.to_date.beginning_of_week(:monday)
    when "daily"  then now.to_date
    when "manual" then now.to_date          # 임시 기본값(컨트롤러에서 원하는 값으로 덮어쓰기 권장)
    when "hybrid" then now.to_date          # 하이브리드도 일단 일자 기준(컨트롤러에서 명확히 설정)
    else
      now.to_date
    end
  end

  # === 발급/사용 헬퍼 (기존 유지, 컨텍스트 인자만 추가) ===
  def self.issue!(user:, classroom:, template:, issued_by: nil, issued_at: Time.zone.now,
                  issuance_basis: "daily", period_start_on: nil, basis_tag: nil)
    period_start_on ||= period_start_for(issuance_basis, now: issued_at)

    create!(
      user: user,
      classroom: classroom,
      coupon_template: template,
      status: :issued,
      issued_at: issued_at,
      issued_by_id: issued_by&.id,
      issuance_basis: issuance_basis,
      period_start_on: period_start_on,
      basis_tag: basis_tag
    )
  end

  def use!(used_at: Time.zone.now)
    update!(status: :used, used_at: used_at)
  end
end