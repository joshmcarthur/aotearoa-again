require "test_helper"

class EditionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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
  end

  test "next_free_publish_on skips occupied dates" do
    tomorrow = Time.zone.tomorrow
    Edition.create!(variant: @variant, publish_on: tomorrow, state: "scheduled")

    other_variant = @candidate.variants.create!(model: @model, prompt: "colourise 2")
    attach_fixture_image(other_variant, name: :colourised_image)
    assert_equal tomorrow + 1.day, Edition.next_free_publish_on
  end

  test "approver schedules edition and deliveries including meta channels when configured" do
    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, true) do
        edition = Editions::Approver.new(@candidate, variant: @variant).call
        assert_equal "scheduled", edition.state
        assert_equal Time.zone.tomorrow, edition.publish_on
        assert_equal %w[email facebook instagram instagram_reel web], edition.deliveries.order(:channel).pluck(:channel)
      end
    end
  end

  test "approver enqueues share video composition for the chosen variant" do
    assert_enqueued_with(job: ComposeShareVideoJob, args: [ @variant.id ]) do
      Editions::Approver.new(@candidate, variant: @variant).call
    end
  end

  test "approver omits meta deliveries when not configured" do
    AppConfig.stub(:instagram_configured?, false) do
      AppConfig.stub(:facebook_configured?, false) do
        edition = Editions::Approver.new(@candidate, variant: @variant).call
        assert_equal %w[email web], edition.deliveries.order(:channel).pluck(:channel)
      end
    end
  end

  test "approver omits meta deliveries without commercial use" do
    @source.update!(usage_flags: %w[Modify Share])
    AppConfig.stub(:instagram_configured?, true) do
      AppConfig.stub(:facebook_configured?, true) do
        edition = Editions::Approver.new(@candidate, variant: @variant).call
        assert_equal %w[email web], edition.deliveries.order(:channel).pluck(:channel)
      end
    end
  end

  test "approver replaces existing edition variant instead of scheduling another" do
    existing = Editions::Approver.new(@candidate, variant: @variant).call
    publish_on = existing.publish_on

    other = @candidate.variants.create!(model: @model, prompt: "colourise alt")
    attach_fixture_image(other, name: :colourised_image)

    edition = Editions::Approver.new(@candidate, variant: other).call

    assert_equal existing.id, edition.id
    assert_equal publish_on, edition.publish_on
    assert_equal other, edition.variant
    assert other.reload.chosen?
    assert_not @variant.reload.chosen?
    assert_equal 1, Edition.where(publish_on: publish_on).count
    assert_equal 1, Edition.joins(:variant).where(variants: { candidate_id: @candidate.id }).count
  end

  test "previous_published returns newer published edition" do
    older = Edition.create!(variant: @variant, publish_on: 2.days.ago.to_date, state: "published", published_at: 2.days.ago)
    middle = Edition.create!(variant: @variant, publish_on: 1.day.ago.to_date, state: "published", published_at: 1.day.ago)
    newer = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "published", published_at: Time.current)

    assert_equal newer, middle.previous_published
    assert_equal middle, older.previous_published
    assert_nil newer.previous_published
  end

  test "next_published returns older published edition" do
    older = Edition.create!(variant: @variant, publish_on: 2.days.ago.to_date, state: "published", published_at: 2.days.ago)
    middle = Edition.create!(variant: @variant, publish_on: 1.day.ago.to_date, state: "published", published_at: 1.day.ago)
    newer = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "published", published_at: Time.current)

    assert_equal middle, newer.next_published
    assert_equal older, middle.next_published
    assert_nil older.next_published
  end

  test "adjacent published methods ignore unpublished editions" do
    published = Edition.create!(variant: @variant, publish_on: 2.days.ago.to_date, state: "published", published_at: 2.days.ago)
    Edition.create!(variant: @variant, publish_on: 1.day.ago.to_date, state: "scheduled")
    current = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "published", published_at: Time.current)

    assert_equal published, current.next_published
    assert_nil published.next_published
  end

  test "public and media urls use default_url_options" do
    edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
    attach_fixture_image(@variant, name: :share_image)
    attach_fixture_image(@variant, name: :composite_image)
    attach_fixture_video(@variant)

    assert_includes edition.public_url, edition.publish_on.iso8601
    assert_includes edition.share_image_url, "/share.jpg"
    assert_includes edition.share_video_url, "/share.mp4"
    assert_includes edition.composite_image_url, "/composite.jpg"
  end

  test "share_video_url is nil without share video" do
    edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")

    assert_nil edition.share_video_url
    # distribution_image / archive_image fall back to colourised_image
    assert_includes edition.share_image_url, "/share.jpg"
    assert_includes edition.composite_image_url, "/composite.jpg"
  end

  test "deliveries_terminal? requires all deliveries succeeded or failed" do
    edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
    edition.deliveries.create!(channel: "web", status: "succeeded")
    edition.deliveries.create!(channel: "email", status: "pending")

    assert_not edition.deliveries_terminal?

    edition.deliveries.find_by(channel: "email").update!(status: "failed")
    assert edition.deliveries_terminal?
  end

  test "delegates distribution_image and archive_image to variant" do
    edition = Edition.create!(variant: @variant, publish_on: Time.zone.today, state: "scheduled")
    assert_equal @variant.distribution_image, edition.distribution_image
    assert_equal @variant.archive_image, edition.archive_image
  end
end
