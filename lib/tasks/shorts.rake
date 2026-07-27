namespace :shorts do
  desc "Compose a 9:16 share video for an edition (attaches Variant#share_video). " \
       "DATE=YYYY-MM-DD OUT=tmp/shorts/demo.mp4 " \
       "Optional: FPS HOLD_START_S MOTION_S HOLD_END_S CAPTION_FADE_S CAPTION_LEAD_S"
  task demo: :environment do
    date = ENV["DATE"].presence
    edition =
      if date
        Edition.find_by!(publish_on: Date.parse(date))
      else
        Edition.published.order(publish_on: :desc).first ||
          Edition.order(publish_on: :desc).first
      end
    abort "No editions found" unless edition

    out = ENV.fetch("OUT") { Rails.root.join("tmp/shorts/#{edition.publish_on.iso8601}.mp4").to_s }

    opts = {
      fps: ENV["FPS"],
      hold_start_s: ENV["HOLD_START_S"],
      motion_s: ENV["MOTION_S"],
      hold_end_s: ENV["HOLD_END_S"],
      caption_fade_s: ENV["CAPTION_FADE_S"],
      caption_lead_s: ENV["CAPTION_LEAD_S"]
    }.compact_blank.transform_values { |v| Float(v) }

    puts "Composing share video for #{edition.publish_on} (#{edition.state}) → attach + #{out}"
    ComposeShareVideoJob.perform_now(edition.variant.id, export_path: out, **opts)
    variant = edition.variant.reload
    abort "share_video missing after compose" unless variant.share_video.attached?
    puts "Attached share_video (#{variant.share_video.blob.byte_size} bytes); wrote #{out}"
  end
end
