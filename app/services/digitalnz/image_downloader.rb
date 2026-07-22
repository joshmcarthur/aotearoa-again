require "faraday"
require "faraday/follow_redirects"
require "stringio"

module Digitalnz
  class ImageDownloader
    class Error < StandardError; end

    SKIP_EXTENSIONS = /\.(tiff?|tif)(\?|$)/i

    def initialize(http: nil)
      @http = http || Faraday.new do |f|
        f.response :follow_redirects
        f.adapter Faraday.default_adapter
      end
    end

    def call(url)
      raise Error, "Missing image URL" if url.blank?
      raise Error, "Refusing archival TIFF download" if url.match?(SKIP_EXTENSIONS)

      response = @http.get(url)
      raise Error, "Download failed (#{response.status})" unless response.success?

      content_type = response.headers["content-type"].to_s.split(";").first.presence || "image/jpeg"
      path = URI.parse(url).path.to_s
      filename = File.basename(path)
      filename = "original.jpg" if filename.blank? || filename == "/"

      {
        io: StringIO.new(response.body),
        filename: filename,
        content_type: content_type
      }
    rescue Faraday::Error, URI::InvalidURIError => e
      raise Error, e.message
    end
  end
end
