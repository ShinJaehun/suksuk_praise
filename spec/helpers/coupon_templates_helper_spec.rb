require 'rails_helper'

RSpec.describe CouponTemplatesHelper, type: :helper do
  describe '#coupon_thumbnail' do
    it 'renders an attached image' do
      tpl = create(:coupon_template)
      tpl.image.attach(
        io: StringIO.new('image'),
        filename: 'coupon.png',
        content_type: 'image/png'
      )

      expect(helper.coupon_thumbnail(tpl)).to include('<img')
    end

    it 'renders a valid default image key' do
      tpl = build(:coupon_template, default_image_key: 'coupon_templates/mychew.png')

      expect(helper.coupon_thumbnail(tpl)).to include('coupon_templates/mychew')
    end

    it 'renders a placeholder when default image key is blank' do
      tpl = build(:coupon_template, default_image_key: nil)

      expect(helper.coupon_thumbnail(tpl)).to include('bg-gray-100')
    end

    it 'renders a placeholder when default image key does not exist' do
      tpl = build(:coupon_template, default_image_key: 'coupon_templates/missing.png')

      expect(helper.coupon_thumbnail(tpl)).to include('bg-gray-100')
    end
  end
end
