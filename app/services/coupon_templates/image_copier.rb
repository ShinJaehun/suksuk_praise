module CouponTemplates
  class ImageCopier
    def self.copy!(source:, target:)
      new(source:, target:).copy!
    end

    def initialize(source:, target:)
      @source = source
      @target = target
    end

    def copy!
      source_attachment = source.image_attachment
      return unless source_attachment&.persisted?

      copy_attachment!(source_attachment.blob)
    rescue ActiveStorage::FileNotFoundError
      false
    end

    private

    attr_reader :source, :target

    def copy_attachment!(source_blob)
      copied_blob = source_blob.open do |file|
        file.rewind

        ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: source_blob.filename.to_s,
          content_type: source_blob.content_type,
          identify: false
        )
      end

      target.image.attach(copied_blob)
      target.image
    end
  end
end
