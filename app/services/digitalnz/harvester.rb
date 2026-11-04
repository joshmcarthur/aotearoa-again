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
        next unless RightsFilter.acceptable?(record)

        file = @downloader.call(attrs[:image_url])
        if ColourPhotographCheck.colour_photograph?(file[:io])
          discard_source(attrs)
          next
        end

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

      candidate = source_item.candidates.create!(status: "pending_review")
      candidate.original_image.attach(**file)
      candidate
    end

    def discard_source(attrs)
      source_item = SourceItem.find_or_initialize_by(digitalnz_id: attrs[:digitalnz_id])
      source_item.assign_attributes(attrs)
      source_item.save!
      source_item.discard! unless source_item.discarded?
    end
  end
end
