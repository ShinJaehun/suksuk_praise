class Classroom < ApplicationRecord
    COMPLIMENT_KING_PERIODS = %w[daily weekly monthly].freeze

    # 교실 삭제 시 관련 칭찬/쿠폰도 함께 삭제
    has_many :classroom_memberships, dependent: :destroy
    has_many :users, through: :classroom_memberships
    has_many :user_coupons, dependent: :destroy
    has_many :compliments, dependent: :destroy

    def students
      users.merge(ClassroomMembership.where(role: "student"))
    end

    def enabled_compliment_king_periods
      COMPLIMENT_KING_PERIODS.select do |period|
        public_send("#{period}_compliment_king_enabled?")
      end
    end
end
