# frozen_string_literal: true

module CouponTemplates
  class DefaultLibrarySeeder
    class InvalidAdminError < StandardError; end

    DEFAULT_COUPONS = [
      {
        title: "쫀득 마이쭈",
        weight: 30,
        active: true,
        default_image_key: "coupon_templates/mychew.png"
      },
      {
        title: "달콤 초콜릿",
        weight: 30,
        active: true,
        default_image_key: "coupon_templates/chocolate.png"
      },
      {
        title: "좋아하는 자리에서 식사하기",
        weight: 30,
        active: true,
        default_image_key: "coupon_templates/lunch_seat.png"
      },
      {
        title: "일주일간 자리 바꾸기",
        weight: 10,
        active: true,
        default_image_key: "coupon_templates/swap.png"
      }
    ].map(&:freeze).freeze

    def self.call!(admin:)
      raise InvalidAdminError, "A persisted administrator account is required." unless admin&.persisted? && admin.admin?

      CouponTemplate.transaction do
        DEFAULT_COUPONS.map do |attributes|
          coupon_template = CouponTemplate
            .where(created_by: admin, bucket: "library")
            .where("LOWER(title) = ?", attributes.fetch(:title).downcase)
            .first_or_initialize

          coupon_template.assign_attributes(
            attributes.merge(created_by: admin, bucket: "library")
          )
          coupon_template.save!
          coupon_template
        end
      end
    end
  end
end
