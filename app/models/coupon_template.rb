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

  before_validation :zero_weight_if_turned_off
  validate :enforce_personal_invariants

  private

  def zero_weight_if_turned_off
    # personal에서 active가 false로 "변경될 때"만 weight를 0으로 만든다.
    return unless bucket == "personal"
    # Rails 7.1: will_save_change_to_active? 사용
    if will_save_change_to_active? && active == false
      self.weight = 0
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
    # 비활성화면 zero_weight_if_inactive 훅으로 항상 0으로 둔다(추가 에러는 불필요)
  end  
end
