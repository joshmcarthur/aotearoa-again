ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<DIGITALNZ_API_KEY>") { AppConfig.dig(:digitalnz, :api_key) }
  config.filter_sensitive_data("<OPENROUTER_API_KEY>") { AppConfig.openrouter_api_key }
  config.filter_sensitive_data("<BUTTONDOWN_API_KEY>") { AppConfig.dig(:buttondown, :api_key) }
  config.ignore_localhost = true
  config.allow_http_connections_when_no_cassette = false
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Domain data is created in tests; RubyLLM Model rows come from schema load/seeds as needed.
    self.use_transactional_tests = true

    setup do
      ActiveStorage::Current.url_options = { host: "www.example.com" }
    end

    def create_source_item(attrs = {})
      SourceItem.create!({
        digitalnz_id: SecureRandom.hex(4),
        title: "Harbour scene",
        description: "A photograph of the waterfront.",
        display_date: "circa 1910",
        year: 1910,
        placename: "Wellington",
        creator: "Unknown",
        content_partner: "Alexander Turnbull Library",
        rights_text: "No known copyright restrictions",
        usage_flags: %w[Modify Share],
        record_url: "https://digitalnz.org/records/123",
        image_url: "https://example.com/photo.jpg",
        dedupe_key: "digitalnz:#{SecureRandom.hex(4)}",
        raw_metadata: {}
      }.merge(attrs))
    end

    def attach_fixture_image(record, name: :original_image)
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")
      record.public_send(name).attach(
        io: File.open(path),
        filename: "mono_plate.jpg",
        content_type: "image/jpeg"
      )
    end
  end
end
