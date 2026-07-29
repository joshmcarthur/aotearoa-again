require "test_helper"

class DeliveryTest < ActiveSupport::TestCase
  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/image-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item
    @candidate = @source.candidates.create!(status: "ready")
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
    @edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
  end

  test "web and email are always applicable" do
    assert @edition.deliveries.build(channel: "web").applicable?
    assert @edition.deliveries.build(channel: "email").applicable?
  end

  test "instagram channels applicable when configured with commercial use" do
    AppConfig.stub(:instagram_configured?, true) do
      assert @edition.deliveries.build(channel: "instagram").applicable?
      assert @edition.deliveries.build(channel: "instagram_reel").applicable?
    end
  end

  test "instagram channels not applicable when not configured" do
    AppConfig.stub(:instagram_configured?, false) do
      assert_not @edition.deliveries.build(channel: "instagram").applicable?
      assert_not @edition.deliveries.build(channel: "instagram_reel").applicable?
    end
  end

  test "meta channels not applicable without commercial use" do
    @source.update!(usage_flags: %w[Modify Share])
    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, true) do
        assert_not @edition.deliveries.build(channel: "instagram").applicable?
        assert_not @edition.deliveries.build(channel: "facebook").applicable?
      end
    end
  end

  test "facebook applicable when configured with commercial use" do
    AppConfig.stub(:facebook_configured?, true) do
      assert @edition.deliveries.build(channel: "facebook").applicable?
    end
  end
end
