require "test_helper"

class EnsureEditionDeliveriesJobTest < ActiveJob::TestCase
  setup do
    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/ensure-deliveries-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item
    @candidate = @source.candidates.create!(status: "ready")
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
    @edition = Edition.create!(variant: @variant, publish_on: Time.zone.tomorrow, state: "scheduled")
  end

  test "creates all channels as pending when meta is configured" do
    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, true) do
        AppConfig.stub(:youtube_configured?, true) do
          AppConfig.stub(:bluesky_configured?, true) do
            EnsureEditionDeliveriesJob.perform_now(edition_ids: [ @edition.id ])
          end
        end
      end
    end

    statuses = @edition.deliveries.order(:channel).pluck(:channel, :status)
    assert_equal [
      [ "bluesky", "pending" ],
      [ "email", "pending" ],
      [ "facebook", "pending" ],
      [ "instagram", "pending" ],
      [ "instagram_reel", "pending" ],
      [ "youtube_short", "pending" ]
    ], statuses
  end

  test "creates inapplicable meta channels as skipped" do
    AppConfig.stub(:instagram_configured?, false) do
      AppConfig.stub(:facebook_configured?, false) do
        AppConfig.stub(:youtube_configured?, false) do
          AppConfig.stub(:bluesky_configured?, false) do
            EnsureEditionDeliveriesJob.perform_now(edition_ids: [ @edition.id ])
          end
        end
      end
    end

    by_channel = @edition.deliveries.index_by(&:channel)
    assert_equal "pending", by_channel.fetch("email").status
    assert_equal "skipped", by_channel.fetch("bluesky").status
    assert_equal "skipped", by_channel.fetch("instagram").status
    assert_equal "skipped", by_channel.fetch("instagram_reel").status
    assert_equal "skipped", by_channel.fetch("facebook").status
    assert_equal "skipped", by_channel.fetch("youtube_short").status
  end

  test "does not change existing delivery statuses" do
    @edition.deliveries.create!(channel: "email", status: "pending")
    @edition.deliveries.create!(channel: "instagram", status: "skipped")

    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, true) do
        AppConfig.stub(:youtube_configured?, true) do
          AppConfig.stub(:bluesky_configured?, true) do
            EnsureEditionDeliveriesJob.perform_now(edition_ids: [ @edition.id ])
          end
        end
      end
    end

    by_channel = @edition.deliveries.reload.index_by(&:channel)
    assert_equal "pending", by_channel.fetch("email").status
    assert_equal "skipped", by_channel.fetch("instagram").status
    assert_equal "pending", by_channel.fetch("instagram_reel").status
    assert_equal "pending", by_channel.fetch("facebook").status
    assert_equal "pending", by_channel.fetch("youtube_short").status
    assert_equal "pending", by_channel.fetch("bluesky").status
  end

  test "batch mode ensures all scheduled editions" do
    other_variant = @candidate.variants.create!(model: @model, prompt: "colourise 2")
    attach_fixture_image(other_variant, name: :colourised_image)
    other = Edition.create!(variant: other_variant, publish_on: Time.zone.tomorrow + 1.day, state: "scheduled")

    AppConfig.stub(:instagram_configured?, false) do
      AppConfig.stub(:facebook_configured?, false) do
        AppConfig.stub(:youtube_configured?, false) do
          AppConfig.stub(:bluesky_configured?, false) do
            EnsureEditionDeliveriesJob.perform_now
          end
        end
      end
    end

    assert_equal Delivery::CHANNELS.sort, @edition.deliveries.order(:channel).pluck(:channel)
    assert_equal Delivery::CHANNELS.sort, other.deliveries.order(:channel).pluck(:channel)
  end
end
