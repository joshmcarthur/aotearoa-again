require "test_helper"

class ComposeShareImageJob
  class ComposerTest < ActiveSupport::TestCase
    test "composites branded share and unbranded composite jpegs within og bounds" do
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")

      result = Composer.new(
        original_path: path,
        colourised_path: path,
        short_url: "http://www.example.com/s/abc123"
      ).call

      assert_equal "composite.jpg", result.composite.filename
      assert_equal "share.jpg", result.share.filename
      assert_equal "image/jpeg", result.composite.content_type
      assert_equal "image/jpeg", result.share.content_type
      assert result.composite.io.size.positive?
      assert result.share.io.size.positive?

      composite = Vips::Image.new_from_buffer(result.composite.io.string, "")
      share = Vips::Image.new_from_buffer(result.share.io.string, "")
      assert_operator composite.width, :<=, Composer::MAX_WIDTH
      assert_operator composite.height, :<=, Composer::MAX_HEIGHT
      assert_equal composite.width, share.width
      assert_equal composite.height, share.height
      # Brand chip should change pixels vs the unbranded composite.
      assert_not_equal result.composite.io.string, result.share.io.string
    end

    test "brand font file is present" do
      assert BrandChip::FONT_PATH.exist?, "expected Fraunces at #{BrandChip::FONT_PATH}"
    end

    test "forces pangocairo fontconfig backend so fontfile is honoured" do
      # macOS Pango defaults to CoreText, which silently ignores fontfile and
      # falls back to Helvetica. Composer must opt into fontconfig first.
      assert_equal "fontconfig", ENV["PANGOCAIRO_BACKEND"]
    end

    test "brand mark metrics match Fraunces, not Helvetica fallback" do
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")
      composer = Composer.new(
        original_path: path,
        colourised_path: path,
        short_url: "http://www.example.com/s/abc123"
      )

      brand = composer.send(:brand_text, 500, 60)
      fraunces = Vips::Image.text(
        Composer::BRAND,
        font: "Fraunces Bold",
        fontfile: Composer::FONT_PATH.to_s,
        width: 500,
        height: 60,
        rgba: true
      )
      assert_equal fraunces.width, brand.width
      assert_equal fraunces.height, brand.height

      # On macOS without fontconfig, fontfile is ignored and Pango falls back to
      # Helvetica Bold — same metrics as asking for Helvetica directly.
      if RUBY_PLATFORM.include?("darwin")
        helvetica = Vips::Image.text(
          Composer::BRAND,
          font: "Helvetica Bold",
          width: 500,
          height: 60,
          rgba: true
        )
        assert_not_equal [ helvetica.width, helvetica.height ], [ brand.width, brand.height ],
          "brand mark metrics match Helvetica — Fraunces fontfile was not used"
      end
    end

    test "raises when brand font file is missing" do
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")
      missing = Rails.root.join("tmp/missing-fraunces-#{SecureRandom.hex(4)}.ttf")
      original = BrandChip::FONT_PATH

      BrandChip.send(:remove_const, :FONT_PATH)
      BrandChip.const_set(:FONT_PATH, missing)
      begin
        error = assert_raises(Composer::Error) do
          Composer.new(
            original_path: path,
            colourised_path: path,
            short_url: "http://www.example.com/s/abc123"
          ).call
        end
        assert_match(/brand font/i, error.message)
      ensure
        BrandChip.send(:remove_const, :FONT_PATH)
        BrandChip.const_set(:FONT_PATH, original)
      end
    end

    test "raises when original is missing" do
      path = Rails.root.join("test/fixtures/files/mono_plate.jpg")

      assert_raises(Composer::Error) do
        Composer.new(
          original_path: "/tmp/missing-original.jpg",
          colourised_path: path,
          short_url: "http://www.example.com/s/abc123"
        ).call
      end
    end
  end
end
