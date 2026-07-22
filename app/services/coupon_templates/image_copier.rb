module CouponTemplates
  class ImageCopier
    class CopyError < StandardError; end

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
    rescue CopyError
      raise
    rescue StandardError => e
      raise CopyError, e.message
    end

    private

    attr_reader :source, :target

    def copy_attachment!(source_blob)
      copied_blob = nil

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
    rescue StandardError
      purge_copied_blob(copied_blob)
      raise
    end

    def purge_copied_blob(copied_blob)
      copied_blob&.purge
    rescue StandardError => e
      Rails.logger.error(
        "[CouponTemplates::ImageCopier] copied_blob_purge_failed blob_id=#{copied_blob&.id} #{e.class}: #{e.message}"
      )
    end
  end
end
