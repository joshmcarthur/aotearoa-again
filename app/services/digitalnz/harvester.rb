module Digitalnz
  class Harvester
    MAX_ATTEMPTS = 5

    def initialize(
      client: Client.new,
      selector: nil,
      downloader: ImageDownloader.new
    )
      @client = client
      @selector = selector || RandomSelector.new(client: client)
      @downloader = downloader
    end

    def call
      MAX_ATTEMPTS.times do
        record = @selector.call
        return nil unless record

        attrs = RecordMapper.to_source_attributes(record)
        next if attrs[:image_url].blank?
        next unless RecordFilter.acceptable?(record)

        file = @downloader.call(attrs[:image_url])
        next unless GreyscaleCheck.greyscale?(file[:io])

        return persist(attrs, file)
      rescue ImageDownloader::Error
        next
      end
      nil
    end

    private

    def persist(attrs, file)
      source_item = SourceItem.find_or_initialize_by(digitalnz_id: attrs[:digitalnz_id])
      source_item.assign_attributes(attrs)
      source_item.save!

      candidate = source_item.candidates.create!(status: "pending_colour")
      candidate.original_image.attach(**file)
      candidate
    end
  end
end
