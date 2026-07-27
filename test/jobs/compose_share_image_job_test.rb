require "test_helper"

class ComposeShareImageJobTest < ActiveJob::TestCase
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

  test "creates share link and attaches composite and share images" do
    encoded = nil
    qr_new = RQRCode::QRCode.method(:new)

    RQRCode::QRCode.stub(:new, lambda { |data|
      encoded = data
      qr_new.call(data)
    }) do
      ComposeShareImageJob.perform_now(@variant.id)
    end

    @variant.reload
    assert @variant.share_link.present?
    assert_equal @variant.share_link.url, encoded
    assert @variant.composite_image.attached?
    assert @variant.share_image.attached?
    assert_equal "image/jpeg", @variant.composite_image.content_type
    assert_equal "image/jpeg", @variant.share_image.content_type
  end
end
