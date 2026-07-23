namespace :share_images do
  desc "Enqueue share image composition for variants missing share_image"
  task backfill: :environment do
    Variant.find_each do |variant|
      next unless variant.colourised_image.attached?
      next if variant.share_image.attached?

      ComposeShareImageJob.perform_later(variant.id)
      puts "Enqueued ComposeShareImageJob for variant #{variant.id}"
    end
  end
end
