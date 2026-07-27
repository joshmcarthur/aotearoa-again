class ComposeShareImageJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(variant_id)
    variant = Variant.find(variant_id)
    return unless variant.colourised_image.attached?
    return unless variant.candidate.original_image.attached?

    share_link = variant.share_link || variant.create_share_link!

    variant.colourised_image.blob.open do |colourised_file|
      variant.candidate.original_image.blob.open do |original_file|
        result = Composer.new(
          original_path: original_file.path,
          colourised_path: colourised_file.path,
          short_url: share_link.url
        ).call

        variant.composite_image.attach(
          io: result.composite.io,
          filename: result.composite.filename,
          content_type: result.composite.content_type
        )
        variant.share_image.attach(
          io: result.share.io,
          filename: result.share.filename,
          content_type: result.share.content_type
        )
      end
    end
  end
end
