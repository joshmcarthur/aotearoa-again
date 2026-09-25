require "test_helper"

class Colourisers::ModelListTest < ActiveSupport::TestCase
  setup do
    Model.where(preferred_for_colourise: true).update_all(preferred_for_colourise: false)
  end

  test "uses listed preferred OpenRouter models" do
    preferred = create_image_model("preferred", preferred_for_colourise: true)
    create_image_model("unlisted-preferred", preferred_for_colourise: true, unlisted_at: Time.current)
    create_image_model("other")

    assert_equal [ preferred, preferred ], Colourisers::ModelList.for_candidate
  end

  test "falls back to listed image-capable OpenRouter models" do
    fallback = create_image_model("fallback")
    create_image_model("unlisted", unlisted_at: Time.current)

    assert_equal [ fallback ], Colourisers::ModelList.for_candidate
  end

  private

  def create_image_model(suffix, **attrs)
    Model.create!(
      {
        model_id: "test/#{suffix}-#{SecureRandom.hex(4)}",
        name: suffix,
        provider: "openrouter",
        modalities: { "input" => [ "image" ], "output" => [ "image" ] }
      }.merge(attrs)
    )
  end
end
