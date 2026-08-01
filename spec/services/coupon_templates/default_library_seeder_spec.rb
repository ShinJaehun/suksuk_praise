require "rails_helper"

RSpec.describe CouponTemplates::DefaultLibrarySeeder, type: :service do
  let(:admin) { create(:user, :admin) }

  let(:expected_attributes) do
    [
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
    ]
  end

  it "creates the four default library coupons for the administrator" do
    coupons = described_class.call!(admin: admin)

    expect(coupons.size).to eq(4)
    expect(coupons).to all(have_attributes(created_by: admin, bucket: "library"))
    expect(coupons.map { |coupon|
      coupon.attributes.symbolize_keys.slice(:title, :weight, :active, :default_image_key)
    }).to match_array(expected_attributes)
  end

  it "keeps only four default coupons when called repeatedly" do
    2.times { described_class.call!(admin: admin) }

    expect(CouponTemplate.where(created_by: admin, bucket: "library").count).to eq(4)
  end

  it "restores changed attributes on an existing default coupon" do
    coupon = create(
      :coupon_template,
      created_by: admin,
      bucket: "library",
      title: "달콤 초콜릿",
      weight: 5,
      active: false,
      default_image_key: "coupon_templates/changed.png"
    )

    described_class.call!(admin: admin)

    expect(coupon.reload).to have_attributes(
      title: "달콤 초콜릿",
      weight: 30,
      active: true,
      default_image_key: "coupon_templates/chocolate.png"
    )
    expect(CouponTemplate.where(created_by: admin, bucket: "library").count).to eq(4)
  end

  it "matches existing titles case-insensitively" do
    stub_const(
      "#{described_class}::DEFAULT_COUPONS",
      [
        {
          title: "Default Reward",
          weight: 100,
          active: true,
          default_image_key: "coupon_templates/default.png"
        }.freeze
      ].freeze
    )
    coupon = create(
      :coupon_template,
      created_by: admin,
      bucket: "library",
      title: "default reward"
    )

    result = described_class.call!(admin: admin)

    expect(result).to contain_exactly(coupon)
    expect(coupon.reload.title).to eq("Default Reward")
  end

  it "rejects a non-administrator" do
    teacher = create(:user, :teacher)

    expect {
      described_class.call!(admin: teacher)
    }.to raise_error(described_class::InvalidAdminError)
  end
end
