require "test_helper"

class RubyLlmOpenrouterImagesPatchTest < ActiveSupport::TestCase
  class Painter
    prepend RubyLlmOpenrouterImagesPatch
  end

  test "sets max_tokens and includes source image content" do
    Tempfile.create([ "bw", ".png" ]) do |file|
      File.binwrite(
        file.path,
        Base64.decode64(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        )
      )

      payload = Painter.new.render_image_payload(
        "Colourise this photo",
        model: "google/gemini-2.5-flash-image",
        size: "1024x1024",
        with: file.path,
        params: { negative_prompt: "watermark", max_tokens: 2048 }
      )

      assert_equal 2048, payload[:max_tokens]
      assert_equal %w[image text], payload[:modalities]
      refute payload.key?(:negative_prompt)

      content = payload.dig(:messages, 0, :content)
      assert_equal "text", content[0][:type]
      assert_equal "image_url", content[1][:type]
      assert_match %r{\Adata:image/png;base64,}, content[1].dig(:image_url, :url)
    end
  end

  test "defaults max_tokens when omitted" do
    payload = Painter.new.render_image_payload(
      "Colourise this photo",
      model: "google/gemini-2.5-flash-image",
      size: nil
    )

    assert_equal RubyLlmOpenrouterImagesPatch::DEFAULT_MAX_TOKENS, payload[:max_tokens]
    assert_equal "Colourise this photo", payload.dig(:messages, 0, :content)
  end
end
