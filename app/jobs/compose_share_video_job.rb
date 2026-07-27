require "fileutils"

class ComposeShareVideoJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  # Renders a 9:16 share short and attaches it to the variant.
  # Requires an Edition (for the on-screen edition label). Optional +export_path+
  # copies the MP4 for local preview (e.g. rake shorts:demo OUT=…).
  def perform(variant_id, export_path: nil, **opts)
    variant = Variant.find(variant_id)
    edition = variant.edition
    return unless edition
    return unless variant.colourised_image.attached?
    return unless variant.candidate.original_image.attached?

    Dir.mktmpdir("aotearoa-share-video-") do |dir|
      out = Pathname(dir).join("share.mp4")
      Renderer.from_edition(edition, out_path: out, **opts)

      File.open(out, "rb") do |io|
        variant.share_video.attach(
          io: io,
          filename: "share-#{edition.publish_on.iso8601}.mp4",
          content_type: "video/mp4"
        )
      end

      if export_path.present?
        export = Pathname(export_path)
        export.dirname.mkpath
        FileUtils.cp(out, export)
      end
    end
  end
end
