require "test_helper"

module Digitalnz
  class HarvestConfigTest < ActiveSupport::TestCase
    test "parses a DigitalNZ query string into API params" do
      config = HarvestConfig.new(
        "query" => "i[category]=Images&i[usage]=Modify&i[usage]=Use commercially&without[subject][]=Portraits"
      )

      assert_equal [ "Images" ], config.search_params["and[category]"]
      assert_equal [ "Modify", "Use commercially" ], config.search_params["and[usage]"]
      assert_equal [ "Portraits" ], config.search_params["without[subject]"]
    end

    test "parses a pasted website or API URL by taking the query string" do
      website = HarvestConfig.new(
        "query" => "https://digitalnz.org/records?i[category]=Images&i[usage]=Modify&i[usage]=Use commercially"
      )
      api = HarvestConfig.new(
        "query" => "https://api.digitalnz.org/v3/records.json?and[category][]=Images&and[usage][]=Modify"
      )

      assert_equal [ "Images" ], website.search_params["and[category]"]
      assert_equal [ "Modify", "Use commercially" ], website.search_params["and[usage]"]
      assert_equal [ "Images" ], api.search_params["and[category]"]
      assert_equal [ "Modify" ], api.search_params["and[usage]"]
    end

    test "include partners with globs and exact names" do
      config = HarvestConfig.new(
        "include" => { "partners" => [ "*Library*", "MOTAT" ] }
      )

      assert config.allowed_partner?("Alexander Turnbull Library")
      assert config.allowed_partner?("MOTAT")
      assert_not config.allowed_partner?("iNaturalist NZ — Mātaki Taiao")
      assert_not config.allowed_partner?(nil)
    end

    test "empty include allows any named partner" do
      config = HarvestConfig.new({})

      assert config.allowed_partner?("iNaturalist NZ — Mātaki Taiao")
      assert_not config.allowed_partner?(nil)
    end

    test "search param keys omit trailing [] so Faraday NestedParamsEncoder can add them" do
      HarvestConfig.current.search_params.each_key do |key|
        assert_not key.end_with?("[]"), key
      end
    end

    test "app YAML query is Images with Modify, Use commercially, and without Portraits" do
      params = HarvestConfig.current.search_params

      assert_equal [ "Images" ], params["and[category]"]
      assert_includes params["and[usage]"], "Modify"
      assert_includes params["and[usage]"], "Use commercially"
      assert_includes params["without[subject]"], "Portraits"
      assert_includes params["without[content_partner]"], "The British Library"
    end

    test "app YAML include globs allow ATL councils museums and extras" do
      config = HarvestConfig.current

      assert config.allowed_partner?("Alexander Turnbull Library")
      assert config.allowed_partner?("Wellington City Council Archives")
      assert config.allowed_partner?("Canterbury Museum")
      assert config.allowed_partner?("Auckland Libraries")
      assert config.allowed_partner?("MOTAT")
      assert_not config.allowed_partner?("iNaturalist NZ — Mātaki Taiao")
    end
  end
end
