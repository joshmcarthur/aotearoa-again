require "test_helper"

module Digitalnz
  class PartnerFilterTest < ActiveSupport::TestCase
    test "allows Alexander Turnbull Library" do
      assert PartnerFilter.allowed?("Alexander Turnbull Library")
    end

    test "allows NZ councils museums and public libraries" do
      [
        "Wellington City Council Archives",
        "Waitaki District Council",
        "Museum of New Zealand Te Papa Tongarewa",
        "Canterbury Museum",
        "Auckland Libraries",
        "Christchurch City Libraries",
        "Palmerston North City Library",
        "Feilding Library",
        "MOTAT",
        "Puke Ariki"
      ].each do |name|
        assert PartnerFilter.allowed?(name), "expected to allow #{name}"
      end
    end

    test "rejects aggregators universities and overseas partners" do
      [
        "iNaturalist NZ — Mātaki Taiao",
        "Figure.NZ",
        "Trove",
        "Digital Public Library of America",
        "Europeana",
        "The British Library",
        "Museums Victoria",
        "University of Otago",
        "Hocken Collections - Uare Taoka o Hākena, University of Otago",
        "National Library of New Zealand",
        "Auckland Art Gallery Toi o Tāmaki"
      ].each do |name|
        assert_not PartnerFilter.allowed?(name), "expected to reject #{name}"
      end
    end

    test "rejects blank names" do
      assert_not PartnerFilter.allowed?(nil)
      assert_not PartnerFilter.allowed?("")
    end
  end
end
