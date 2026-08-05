require "test_helper"

module StandardSite
  class DocumentPublisherTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :uploads, :records

      def initialize
        @uploads = []
        @records = []
      end

      def upload_blob(bytes, content_type:)
        @uploads << { bytes: bytes, content_type: content_type }
        {
          "$type" => "blob",
          "ref" => { "$link" => "bafycover" },
          "mimeType" => content_type,
          "size" => bytes.bytesize
        }
      end

      def create_record(collection:, record:)
        @records << { collection: collection, record: record }
        { uri: "at://did:plc:test/#{collection}/doc1", cid: "bafydoc1" }
      end
    end

    setup do
      @model = Model.openrouter.image_capable.first || Model.create!(
        model_id: "test/standard-site-model",
        name: "Test Image",
        provider: "openrouter",
        modalities: { "input" => [ "image" ], "output" => [ "image" ] }
      )
      @source = create_source_item
      @candidate = @source.candidates.create!(status: "ready")
      @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(@variant, name: :colourised_image)
      attach_fixture_image(@variant, name: :share_image)
      @edition = Edition.create!(variant: @variant, publish_on: Date.new(2026, 7, 25), state: "published")
      @delivery = @edition.deliveries.create!(channel: "bluesky", status: "pending")
      @client = FakeClient.new
    end

    test "creates document record and stores refs in delivery metadata" do
      AppConfig.stub(:bluesky_publication_uri, "at://did:plc:test/site.standard.publication/pub1") do
        ref = DocumentPublisher.call(@edition, @delivery, client: @client)
      end

      assert_equal "at://did:plc:test/site.standard.document/doc1", ref[:uri]
      assert_equal "bafydoc1", @delivery.metadata_get("standard_site_document_cid")
      assert_equal "site.standard.document", @client.records.first[:collection]
      assert_equal "/editions/2026-07-25", @client.records.first[:record]["path"]
      assert_equal 1, @client.uploads.size
    end

    test "is idempotent when metadata already present" do
      @delivery.update!(
        metadata: {
          "standard_site_document_uri" => "at://did:plc:test/site.standard.document/existing",
          "standard_site_document_cid" => "bafyexisting"
        }
      )

      ref = DocumentPublisher.call(@edition, @delivery, client: @client)

      assert_equal "at://did:plc:test/site.standard.document/existing", ref[:uri]
      assert_empty @client.records
      assert_empty @client.uploads
    end
  end
end
