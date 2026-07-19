require "rails_helper"

RSpec.describe CouponTemplates::AutoAdopter, type: :service do
  it "creates an onboarding coupon with its source and an independent image blob" do
    admin = create(:user, :admin)
    source = create(
      :coupon_template,
      created_by: admin,
      bucket: "library",
      active: true,
      default_image_key: "coupon_templates/chocolate.png"
    )
    source.image.attach(
      io: StringIO.new("onboarding image"),
      filename: "onboarding.png",
      content_type: "image/png"
    )

    teacher = create(:user, :teacher)
    personal = CouponTemplate.find_by!(created_by: teacher, source_template: source)

    expect(personal.image).to be_attached
    expect(personal.image.blob_id).not_to eq(source.image.blob_id)
    expect(personal.image.download).to eq(source.image.download)
    expect(personal.default_image_key).to eq(source.default_image_key)
  end

  it "does not change an onboarded personal coupon when the source changes later" do
    admin = create(:user, :admin)
    source = create(
      :coupon_template,
      created_by: admin,
      bucket: "library",
      title: "처음 제목",
      active: true,
      default_image_key: "coupon_templates/chocolate.png"
    )
    source.image.attach(
      io: StringIO.new("original image"),
      filename: "original.png",
      content_type: "image/png"
    )
    teacher = create(:user, :teacher)
    personal = CouponTemplate.find_by!(created_by: teacher, source_template: source)
    personal_blob_id = personal.image.blob_id

    source.update!(title: "변경된 제목", default_image_key: "coupon_templates/mychew.png")
    source.image.attach(
      io: StringIO.new("changed image"),
      filename: "changed.png",
      content_type: "image/png"
    )

    expect(personal.reload.title).to eq("처음 제목")
    expect(personal.default_image_key).to eq("coupon_templates/chocolate.png")
    expect(personal.image.blob_id).to eq(personal_blob_id)
    expect(personal.image.download).to eq("original image")
  end

end
