require "test_helper"

class RegenerateVariantJobTest < ActiveJob::TestCase
  class FakeColouriser
    def call(attachment:, model:)
      {
        model: model,
        prompt: Colourisers::Prompt::TEXT,
        io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/mono_plate.jpg"))),
        filename: "colourised.jpg",
        content_type: "image/jpeg"
      }
    end
  end

  setup do
    @model = Model.create!(
      model_id: "test/regenerate-variant-#{SecureRandom.hex(4)}",
      name: "Test Image",
      provider: "openrouter",
      preferred_for_colourise: true,
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @source = create_source_item
    @candidate = @source.candidates.create!(status: "ready")
    attach_fixture_image(@candidate)
    @variant = @candidate.variants.create!(model: @model, prompt: "colourise", chosen: true)
    attach_fixture_image(@variant, name: :colourised_image)
    @edition = Edition.create!(variant: @variant, publish_on: Time.zone.tomorrow, state: "scheduled")
  end

  test "replaces colourised image and enqueues share jobs" do
    Colourisers::RubyLlmColouriser.define_singleton_method(:new) { FakeColouriser.new }

    assert_enqueued_with(job: ComposeShareImageJob, args: [ @variant.id ]) do
      assert_enqueued_with(job: ComposeShareVideoJob, args: [ @variant.id ]) do
        RegenerateVariantJob.perform_now(@variant.id)
      end
    end

    @candidate.reload
    assert_equal "ready", @candidate.status
    assert @variant.reload.colourised_image.attached?
    assert_equal 1, @candidate.variants.count
  ensure
    Colourisers::RubyLlmColouriser.singleton_class.remove_method(:new)
  end

  test "uses specified model when model_id is given" do
    other_model = Model.create!(
      model_id: "test/regenerate-variant-other-#{SecureRandom.hex(4)}",
      name: "Other Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    Colourisers::RubyLlmColouriser.define_singleton_method(:new) { FakeColouriser.new }

    RegenerateVariantJob.perform_now(@variant.id, model_id: other_model.id)

    assert_equal other_model, @variant.reload.model
  ensure
    Colourisers::RubyLlmColouriser.singleton_class.remove_method(:new)
  end
end
