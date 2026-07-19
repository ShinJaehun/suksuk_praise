require "rails_helper"

RSpec.describe CouponTemplates::ImageCopier, type: :service do
  def attach_image(record, content:, filename: "coupon.png", content_type: "image/png")
    record.image.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )
  end

  let(:admin) { create(:user, :admin) }
  let!(:teacher) { create(:user, :teacher) }
  let(:source) do
    create(
      :coupon_template,
      created_by: admin,
      bucket: "library",
      default_image_key: "coupon_templates/chocolate.png"
    )
  end
  let(:target) do
    create(
      :coupon_template,
      created_by: teacher,
      source_template: source,
      default_image_key: CouponTemplate::DEFAULT_IMAGE_KEY
    )
  end

  it "copies an attached image into an independent blob" do
    attach_image(source, content: "source bytes", filename: "reward.png")

    described_class.copy!(source: source, target: target)

    expect(target.reload.image).to be_attached
    expect(target.image.blob_id).not_to eq(source.image.blob_id)
    expect(target.image.blob.filename.to_s).to eq("reward.png")
    expect(target.image.blob.content_type).to eq("image/png")
    expect(target.image.blob.checksum).to eq(source.image.blob.checksum)
    expect(target.image.download).to eq(source.image.download)
  end

  it "keeps the copied image when the source attachment is replaced" do
    attach_image(source, content: "image A", filename: "a.png")
    described_class.copy!(source: source, target: target)
    target_blob_id = target.reload.image.blob_id

    attach_image(source, content: "image B", filename: "b.png")

    expect(target.reload.image).to be_attached
    expect(target.image.blob_id).to eq(target_blob_id)
    expect(target.image.download).to eq("image A")
  end

  it "does not attach an image or change the target default when the source has no attachment" do
    result = described_class.copy!(source: source, target: target)

    expect(result).to be_nil
    expect(target.reload.image).not_to be_attached
    expect(target.default_image_key).to eq(CouponTemplate::DEFAULT_IMAGE_KEY)
  end
end
