module Digitalnz
  class Harvester
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
      record = @selector.call
      return nil unless record

      attrs = RecordMapper.to_source_attributes(record)
      return nil if attrs[:image_url].blank?
      return nil unless RightsFilter.acceptable?(record)

      source_item = SourceItem.find_or_initialize_by(digitalnz_id: attrs[:digitalnz_id])
      source_item.assign_attributes(attrs)
      source_item.save!

      candidate = source_item.candidates.create!(status: "pending_colour")
      file = @downloader.call(attrs[:image_url])
      candidate.original_image.attach(**file)
      candidate
    end
  end
end
