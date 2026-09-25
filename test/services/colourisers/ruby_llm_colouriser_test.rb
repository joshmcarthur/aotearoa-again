require "test_helper"

class Colourisers::RubyLlmColouriserTest < ActiveSupport::TestCase
  FakeTokens = Struct.new(:input, :output)
  FakeCost = Struct.new(:total)
  FakeImage = Struct.new(:blob, :mime_type, :tokens, :cost) do
    def to_blob = blob
  end

  setup do
    @model = Model.create!(
      model_id: "test/colourise-#{SecureRandom.hex(4)}",
      name: "Test Image",
      provider: "openrouter",
      modalities: { "input" => [ "image" ], "output" => [ "image" ] }
    )
    @candidate = create_source_item.candidates.create!(status: "pending_colour")
    attach_fixture_image(@candidate)
  end

  test "paints with the original image and records usage" do
    image = FakeImage.new("PNGDATA", "image/png", FakeTokens.new(11, 22), FakeCost.new(0.04))
    captured = nil

    paint = lambda do |prompt, **kwargs|
      captured = kwargs.merge(prompt: prompt)
      image
    end

    result = nil
    RubyLLM.stub(:paint, paint) do
      result = Colourisers::RubyLlmColouriser.new.call(attachment: @candidate.original_image, model: @model)
    end

    assert_equal Colourisers::Prompt::TEXT, captured[:prompt]
    assert_equal @model.model_id, captured[:model]
    assert_equal :openrouter, captured[:provider]
    assert_equal @candidate.original_image, captured[:with]
    assert_equal({ output_format: "png" }, captured[:provider_options])
    assert_equal "PNGDATA", result[:io].read
    assert_equal "image/png", result[:content_type]
    assert_equal({ "input_tokens" => 11, "output_tokens" => 22, "cost" => 0.04 }, result[:usage])
  end

  test "wraps RubyLLM errors" do
    paint = lambda { |*| raise RubyLLM::Error, "provider down" }

    error = assert_raises(Colourisers::RubyLlmColouriser::Error) do
      RubyLLM.stub(:paint, paint) do
        Colourisers::RubyLlmColouriser.new.call(attachment: @candidate.original_image, model: @model)
      end
    end

    assert_equal "provider down", error.message
  end
end
