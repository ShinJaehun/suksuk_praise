require "rails_helper"

RSpec.describe CouponTemplates::AutoAdopter, type: :service do
  def attach_image(record, content:, filename: "coupon.png")
    record.image.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: "image/png"
    )
  end

  def fail_copy_attach_for_source(source, error: RuntimeError.new("attach failed"))
    allow_any_instance_of(ActiveStorage::Attached::One).to receive(:attach).and_wrap_original do |method, *args, **kwargs|
      attachment = method.receiver
      record = attachment.instance_variable_get(:@record)

      raise error if record.is_a?(CouponTemplate) && record.source_template_id == source.id

      method.call(*args, **kwargs)
    end

    error
  end

  it "creates an onboarding coupon with its source and an independent image blob" do
    admin = create(:user, :admin)
    source = create(
      :coupon_template,
      created_by: admin,
      bucket: "library",
      active: true,
      default_image_key: "coupon_templates/chocolate.png"
    )
    attach_image(source, content: "onboarding image", filename: "onboarding.png")

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
    attach_image(source, content: "original image", filename: "original.png")
    teacher = create(:user, :teacher)
    personal = CouponTemplate.find_by!(created_by: teacher, source_template: source)
    personal_blob_id = personal.image.blob_id

    source.update!(title: "변경된 제목", default_image_key: "coupon_templates/mychew.png")
    attach_image(source, content: "changed image", filename: "changed.png")

    expect(personal.reload.title).to eq("처음 제목")
    expect(personal.default_image_key).to eq("coupon_templates/chocolate.png")
    expect(personal.image.blob_id).to eq(personal_blob_id)
    expect(personal.image.download).to eq("original image")
  end

  it "creates an onboarding coupon when the source has no image" do
    admin = create(:user, :admin)
    source = create(
      :coupon_template,
      created_by: admin,
      bucket: "library",
      title: "이미지 없는 추천",
      active: true
    )

    teacher = create(:user, :teacher)
    personal = CouponTemplate.find_by!(created_by: teacher, source_template: source)

    expect(personal.image).not_to be_attached
    expect(personal.title).to eq(source.title)
  end

  it "skips only the source whose image copy fails during teacher creation" do
    admin = create(:user, :admin)
    successful_source = create(:coupon_template, created_by: admin, bucket: "library", title: "성공 추천", active: true)
    failed_source = create(:coupon_template, created_by: admin, bucket: "library", title: "실패 추천", active: true)
    no_image_source = create(:coupon_template, created_by: admin, bucket: "library", title: "이미지 없는 추천", active: true)
    attach_image(successful_source, content: "successful image", filename: "successful.png")
    attach_image(failed_source, content: "failed image", filename: "failed.png")
    failed_source_blob_id = failed_source.image.blob_id
    failed_source_attachment_id = failed_source.image_attachment.id
    blob_count = ActiveStorage::Blob.count
    attachment_count = ActiveStorage::Attachment.count
    allow(Rails.logger).to receive(:error)
    fail_copy_attach_for_source(failed_source)

    expect {
      @teacher = create(:user, :teacher)
    }.not_to raise_error

    successful_personal = CouponTemplate.find_by!(created_by: @teacher, source_template: successful_source)
    no_image_personal = CouponTemplate.find_by!(created_by: @teacher, source_template: no_image_source)

    expect(CouponTemplate.find_by(created_by: @teacher, source_template: failed_source)).to be_nil
    expect(successful_personal.image.blob_id).not_to eq(successful_source.image.blob_id)
    expect(successful_personal.image.download).to eq("successful image")
    expect(no_image_personal.image).not_to be_attached
    expect(ActiveStorage::Blob.count).to eq(blob_count + 1)
    expect(ActiveStorage::Attachment.count).to eq(attachment_count + 1)
    expect(failed_source.reload.image.blob_id).to eq(failed_source_blob_id)
    expect(failed_source.image_attachment.id).to eq(failed_source_attachment_id)
    expect(successful_personal.image.blob.service.exist?(successful_personal.image.blob.key)).to eq(true)
    expect(Rails.logger).to have_received(:error).with(
      a_string_including("source_template_id=#{failed_source.id}", "CouponTemplates::ImageCopier::CopyError")
    )
  end
end
