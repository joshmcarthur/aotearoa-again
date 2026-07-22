require "test_helper"

module Publishing
  class OrchestratorTest < ActiveSupport::TestCase
    class FakeButtondown
      attr_reader :calls

      def initialize
        @calls = []
      end

      def create_draft(subject:, body:)
        @calls << { subject: subject, body: body }
        { "id" => "bd_123" }
      end
    end

    setup do
      @model = Model.openrouter.image_capable.first || Model.create!(
        model_id: "test/image-model",
        name: "Test Image",
        provider: "openrouter",
        modalities: { "input" => [ "image" ], "output" => [ "image" ] }
      )
      @source = create_source_item
      @candidate = @source.candidates.create!(status: "ready")
      attach_fixture_image(@candidate)
      @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
      attach_fixture_image(@variant, name: :colourised_image)
      @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
      @edition.deliveries.create!(channel: "web", status: "pending")
      @edition.deliveries.create!(channel: "email", status: "pending")
    end

    test "publishes web and email idempotently" do
      fake = FakeButtondown.new
      Orchestrator.new(@edition, buttondown: fake).call

      @edition.reload
      assert_equal "published", @edition.state
      assert_equal "succeeded", @edition.deliveries.find_by(channel: "web").status
      email = @edition.deliveries.find_by(channel: "email")
      assert_equal "succeeded", email.status
      assert_equal "bd_123", email.external_id
      assert_equal 1, fake.calls.size
      assert_equal @source.title, fake.calls.first[:subject]

      Orchestrator.new(@edition, buttondown: fake).call
      assert_equal 1, fake.calls.size
    end
  end
end
