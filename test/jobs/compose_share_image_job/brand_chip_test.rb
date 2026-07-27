require "test_helper"

class ComposeShareImageJob
  class BrandChipTest < ActiveSupport::TestCase
    SHARE_URL = "https://example.com/s/abc123"

    test "QR encodes the absolute share URL" do
      encoded = nil
      qr_new = RQRCode::QRCode.method(:new)

      RQRCode::QRCode.stub(:new, lambda { |data|
        encoded = data
        qr_new.call(data)
      }) do
        BrandChip.send(:qr_rgba, SHARE_URL, 64)
      end

      assert_equal SHARE_URL, encoded
    end

    test "QR is white on a transparent background at the requested size" do
      qr = BrandChip.send(:qr_rgba, SHARE_URL, 96)

      assert_equal 96, qr.width
      assert_equal 96, qr.height
      assert_equal 4, qr.bands

      alpha = qr.extract_band(3)
      assert_equal 0, alpha.min
      assert_operator alpha.max, :>, 0

      rgb = qr.extract_band(0, n: 3)
      assert_operator rgb.max, :>=, 240
    end

    test "build rejects relative share paths" do
      error = assert_raises(Composer::Error) do
        BrandChip.build(800, "/s/abc123")
      end
      assert_match(/absolute/i, error.message)
    end
  end
end
