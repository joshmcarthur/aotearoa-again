require "test_helper"

class ComposeShareVideoJobTest < ActiveJob::TestCase
  setup do
    @path = Rails.root.join("test/fixtures/files/mono_plate.jpg")
    skip "fixture missing" unless @path.exist?

    @model = Model.openrouter.image_capable.first || Model.create!(
      model_id: "test/video-image-model",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item(
      title: "Test plate",
      record_url: "http://natlib.govt.nz/records/1",
      content_partner: "Alexander Turnbull Library",
      rights_text: "CC BY 4.0"
    )
    @candidate = @source.candidates.create!(status: "ready")
    attach_fixture_image(@candidate)
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
    @edition = Edition.create!(variant: @variant, publish_on: Date.new(2026, 7, 22), state: "scheduled")
  end

  test "no-ops when variant has no edition" do
    @edition.destroy!
    ComposeShareVideoJob.perform_now(@variant.id)
    assert_not @variant.reload.share_video.attached?
  end

  test "attaches share_video when edition and images present" do
    skip "ffmpeg not available" unless system("ffmpeg", "-version", out: File::NULL, err: File::NULL)

    ComposeShareVideoJob.perform_now(
      @variant.id,
      fps: 10,
      hold_start_s: 0.2,
      motion_s: 0.3,
      hold_end_s: 0.2
    )
    assert @variant.reload.share_video.attached?
    assert_equal "video/mp4", @variant.share_video.content_type
  end
end
