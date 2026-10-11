require "test_helper"

module Digitalnz
  class HarvestConfigTest < ActiveSupport::TestCase
    test "parses a DigitalNZ website search URL into API params" do
      config = HarvestConfig.new(
        "search_url" => "https://digitalnz.org/records?i[category]=Images&i[usage]=Modify&i[usage]=Use commercially"
      )

      assert_equal [ "Images" ], config.search_params["and[category]"]
      assert_equal [ "Modify", "Use commercially" ], config.search_params["and[usage]"]
    end

    test "parses an API search URL" do
      config = HarvestConfig.new(
        "search_url" => "https://api.digitalnz.org/v3/records.json?and[category][]=Images&and[usage][]=Modify"
      )

      assert_equal [ "Images" ], config.search_params["and[category]"]
      assert_equal [ "Modify" ], config.search_params["and[usage]"]
    end

    test "adds exact exclude subjects as without[subject] search params" do
      config = HarvestConfig.new(
        "search_url" => "https://digitalnz.org/records?i[category]=Images",
        "exclude" => { "subjects" => [ "Portraits", "*colour*" ] }
      )

      assert_equal [ "Portraits" ], config.search_params["without[subject]"]
    end

    test "include then exclude partners with globs and exact names" do
      config = HarvestConfig.new(
        "include" => { "partners" => [ "*Library*", "MOTAT" ] },
        "exclude" => { "partners" => [ "The British Library", "*University*" ] }
      )

      assert config.allowed_partner?("Alexander Turnbull Library")
      assert config.allowed_partner?("MOTAT")
      assert_not config.allowed_partner?("The British Library")
      assert_not config.allowed_partner?("Hocken Collections - University of Otago")
      assert_not config.allowed_partner?("iNaturalist NZ — Mātaki Taiao")
      assert_not config.allowed_partner?(nil)
    end

    test "empty include allows any partner that is not excluded" do
      config = HarvestConfig.new("exclude" => { "partners" => [ "*University*" ] })

      assert config.allowed_partner?("iNaturalist NZ — Mātaki Taiao")
      assert_not config.allowed_partner?("University of Otago")
    end

    test "excludes records by title substring, subject, and type" do
      config = HarvestConfig.new(
        "exclude" => {
          "subjects" => [ "Portraits", "*colour*" ],
          "types" => [ "Map", "*portrait*" ],
          "title_contains" => [ "portrait", "colour" ]
        }
      )

      assert config.excluded_record?(title: "Portrait of Jane", subject: [], dc_type: [])
      assert config.excluded_record?(title: "Street", subject: [ "Portraits" ], dc_type: [])
      assert config.excluded_record?(title: "Street", subject: [ "coloured image" ], dc_type: [])
      assert config.excluded_record?(title: "Street", subject: [], dc_type: [ "Map" ])
      assert_not config.excluded_record?(title: "Street", subject: [ "Womens clothing" ], dc_type: [ "Photograph - print" ])
    end

    test "search param keys omit trailing [] so Faraday NestedParamsEncoder can add them" do
      HarvestConfig.current.search_params.each_key do |key|
        assert_not key.end_with?("[]"), key
      end
    end

    test "exclude wins when a partner matches both include and exclude" do
      config = HarvestConfig.new(
        "include" => { "partners" => [ "*Library*" ] },
        "exclude" => { "partners" => [ "The British Library" ] }
      )

      assert config.allowed_partner?("Alexander Turnbull Library")
      assert_not config.allowed_partner?("The British Library")
    end

    test "app YAML search URL is Images with Modify and Use commercially" do
      params = HarvestConfig.current.search_params

      assert_equal [ "Images" ], params["and[category]"]
      assert_includes params["and[usage]"], "Modify"
      assert_includes params["and[usage]"], "Use commercially"
    end

    test "app YAML allows ATL councils museums and extras" do
      config = HarvestConfig.current

      assert config.allowed_partner?("Alexander Turnbull Library")
      assert config.allowed_partner?("Wellington City Council Archives")
      assert config.allowed_partner?("Canterbury Museum")
      assert config.allowed_partner?("Auckland Libraries")
      assert config.allowed_partner?("MOTAT")
      assert_not config.allowed_partner?("The British Library")
      assert_not config.allowed_partner?("National Library of New Zealand")
    end
  end
end
