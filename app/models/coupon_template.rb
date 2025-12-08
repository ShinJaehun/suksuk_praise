class CouponTemplate < ApplicationRecord
  has_many :user_coupons, dependent: :restrict_with_exception
  belongs_to :created_by, class_name: "User"

  validates :title, presence: true
  validates :weight, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :bucket, presence: true, inclusion: { in: %w[personal library] }
  validates :title, uniqueness: {
    scope: %i[created_by_id bucket],
    case_sensitive: false,
    message: :already_in_bucket
  }

  scope :active, -> { where(active: true) }
  scope :by_bucket, ->(bucket) { where(bucket: bucket) }
  scope :owned_by, ->(user_id) { where(created_by_id: user_id) }
  scope :ordered_by_title, -> { order(:title) }
  scope :personal_for, ->(user) { owned_by(user.id).by_bucket("personal") }

  # 새 교사 계정이 만들어질 때 개인 세트로 복제할 수 있는 라이브러리 쿠폰 목록
  scope :library_onboarding_candidates, -> {
    joins(:created_by)
      .merge(User.where(role: "admin"))
      .where(bucket: "library", active: true)
  }

  # personal 세트에서는 항상 두 상태만 허용한다.
  # - (active: true,  weight > 0)
  # - (active: false, weight = 0)
  # library는 이 불변식의 대상이 아니며, 관리자가 자유롭게 weight/active를 조절할 수 있다.
  before_validation :sync_weight_and_active  
  validate :enforce_personal_invariants

  private

  def sync_weight_and_active
    # personal 세트에만 강한 불변식 적용
    return unless bucket == "personal"

    w = weight.to_i
    a = !!active

    if w <= 0
      # 가중치가 0 이하라면 무조건 "꺼진" 상태로 정규화
      self.weight = 0
      self.active = false
    elsif !a
      # active=false 인 상태에서는 항상 weight=0 으로 유지
      self.weight = 0
      self.active = false
    else
      # 정상 케이스: active=true && weight>0
      self.weight = w
      self.active = true
    end
  end

  def enforce_personal_invariants
    # personal 세트에만 강한 불변식 적용
    return unless bucket == "personal"
    # 활성인데 가중치 0은 금지(UX에서도 버튼 비활성/토스트로 보조)
    if active && weight.to_i == 0
      errors.add(:base, I18n.t("errors.coupons.active_requires_weight",
                               default: "활성화하려면 가중치가 0보다 커야 합니다."))
    end
    # 비활성화면 sync_weight_and_active 훅으로 항상 0으로 둔다(추가 에러는 불필요)
  end  
end
