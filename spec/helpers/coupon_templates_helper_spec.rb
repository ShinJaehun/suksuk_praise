require 'rails_helper'

RSpec.describe CouponTemplatesHelper, type: :helper do
  describe '#coupon_thumbnail_source' do
    it 'prefers its own attached image over the source image' do
      teacher = create(:user, :teacher)
      source = create(:coupon_template, created_by: create(:user, :admin), bucket: 'library')
      source.image.attach(
        io: StringIO.new('source image'),
        filename: 'source.png',
        content_type: 'image/png'
      )
      tpl = create(:coupon_template, created_by: teacher, source_template: source)
      tpl.image.attach(
        io: StringIO.new('own image'),
        filename: 'own.png',
        content_type: 'image/png'
      )

      result = helper.coupon_thumbnail_source(tpl)

      expect(result).to eq(helper.url_for(tpl.image_attachment))
      expect(result).not_to eq(helper.url_for(source.image_attachment))
    end

    it 'does not fall back to the source attached image' do
      teacher = create(:user, :teacher)
      source = create(:coupon_template, created_by: create(:user, :admin), bucket: 'library')
      source.image.attach(
        io: StringIO.new('source image'),
        filename: 'source.png',
        content_type: 'image/png'
      )
      tpl = create(:coupon_template, created_by: teacher, source_template: source)

      expect(helper.coupon_thumbnail_source(tpl)).to eq(helper.asset_path(CouponTemplate::DEFAULT_IMAGE_KEY))
    end

    it 'uses its own valid default image even when the source has another default' do
      source = create(
        :coupon_template,
        created_by: create(:user, :admin),
        bucket: 'library',
        default_image_key: 'coupon_templates/chocolate.png'
      )
      tpl = build(
        :coupon_template,
        source_template: source,
        default_image_key: 'coupon_templates/mychew.png'
      )

      expect(helper.coupon_thumbnail_source(tpl)).to eq(helper.asset_path('coupon_templates/mychew.png'))
    end

    it 'does not fall back to the source default image' do
      source = create(
        :coupon_template,
        created_by: create(:user, :admin),
        bucket: 'library',
        default_image_key: 'coupon_templates/chocolate.png'
      )
      tpl = build(
        :coupon_template,
        source_template: source,
        default_image_key: CouponTemplate::DEFAULT_IMAGE_KEY
      )

      expect(helper.coupon_thumbnail_source(tpl)).to eq(helper.asset_path(CouponTemplate::DEFAULT_IMAGE_KEY))
    end

    it 'uses the generic default image last' do
      tpl = build(:coupon_template, default_image_key: nil)

      expect(helper.coupon_thumbnail_source(tpl)).to eq(helper.asset_path(CouponTemplate::DEFAULT_IMAGE_KEY))
    end

    it 'does not use an unrelated source for a directly created coupon' do
      create(:coupon_template, default_image_key: 'coupon_templates/chocolate.png')
      tpl = build(:coupon_template, source_template: nil, default_image_key: nil)

      expect(helper.coupon_thumbnail_source(tpl)).to eq(helper.asset_path(CouponTemplate::DEFAULT_IMAGE_KEY))
    end

    it 'ignores an unsaved attachment change when rendering a validation error' do
      tpl = build(:coupon_template, default_image_key: 'coupon_templates/mychew.png')
      tpl.image.attach(
        io: StringIO.new('replacement'),
        filename: 'replacement.png',
        content_type: 'image/png'
      )

      expect(helper.coupon_thumbnail_source(tpl)).to eq(helper.asset_path('coupon_templates/mychew.png'))
    end
  end

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

    it 'renders the generic default when default image key is blank' do
      tpl = build(:coupon_template, default_image_key: nil)

      expect(helper.coupon_thumbnail(tpl)).to include('coupon_templates/default')
    end

    it 'renders the generic default when default image key does not exist' do
      tpl = build(:coupon_template, default_image_key: 'coupon_templates/missing.png')

      expect(helper.coupon_thumbnail(tpl)).to include('coupon_templates/default')
    end

    it 'uses a provided thumbnail class' do
      tpl = build(:coupon_template, default_image_key: nil)

      expect(helper.coupon_thumbnail(tpl, css_class: 'custom-thumbnail')).to include('custom-thumbnail')
    end
  end
end
