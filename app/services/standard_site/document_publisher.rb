module StandardSite
  class DocumentPublisher
    def self.call(edition, delivery, client: Bluesky::Client.new)
      new(edition, delivery, client: client).call
    end

    def initialize(edition, delivery, client:)
      @edition = edition
      @delivery = delivery
      @client = client
      @copy = edition.copy
    end

    def call
      existing_uri = @delivery.metadata_get("standard_site_document_uri")
      existing_cid = @delivery.metadata_get("standard_site_document_cid")
      return { uri: existing_uri, cid: existing_cid } if existing_uri.present? && existing_cid.present?

      image = @edition.distribution_image
      raise Bluesky::Client::Error, "Share image missing" unless image.attached?

      bytes = image.download
      content_type = image.content_type.presence || "image/jpeg"
      cover_blob = @client.upload_blob(bytes, content_type: content_type)

      publication_uri = AppConfig.bluesky_publication_uri
      raise Bluesky::Client::Error, "Bluesky publication URI missing" if publication_uri.blank?

      record = {
        "$type" => "site.standard.document",
        "site" => publication_uri,
        "title" => @copy.title,
        "path" => edition_path,
        "description" => @copy.caption.to_s.truncate(3000),
        "publishedAt" => published_at,
        "textContent" => document_text_content,
        "coverImage" => cover_blob
      }

      ref = @client.create_record(collection: "site.standard.document", record: record)
      @delivery.merge_metadata!(
        standard_site_document_uri: ref[:uri],
        standard_site_document_cid: ref[:cid]
      )
      ref
    end

    private

    def edition_path
      Rails.application.routes.url_helpers.edition_path(@edition)
    end

    def published_at
      (@edition.published_at || @edition.publish_on.in_time_zone.beginning_of_day).utc.iso8601(3)
    end

    def document_text_content
      [
        @copy.caption,
        @copy.body_text,
        @copy.ai_notice
      ].compact.join("\n\n")
    end
  end
end
