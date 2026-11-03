require "test_helper"

module Digitalnz
  class HarvestConfigTest < ActiveSupport::TestCase
    test "merges url query and params into API search params" do
      config = HarvestConfig.new(
        "url" => "https://digitalnz.org/records?i[category]=Images",
        "params" => { "i[usage]" => [ "Modify", "Use commercially" ] }
      )

      assert_equal [ "Images" ], config.search_params["and[category]"]
      assert_equal [ "Modify", "Use commercially" ], config.search_params["and[usage]"]
    end

    test "parses params from a pasted website or API URL" do
      website = HarvestConfig.new(
        "url" => "https://digitalnz.org/records?i[category]=Images&i[usage]=Modify&i[usage]=Use commercially"
      )
      api = HarvestConfig.new(
        "url" => "https://api.digitalnz.org/v3/records.json?and[category][]=Images&and[usage][]=Modify"
      )

      assert_equal [ "Images" ], website.search_params["and[category]"]
      assert_equal [ "Modify", "Use commercially" ], website.search_params["and[usage]"]
      assert_equal [ "Images" ], api.search_params["and[category]"]
      assert_equal [ "Modify" ], api.search_params["and[usage]"]
    end

    test "parses a scheme-less query string" do
      config = HarvestConfig.new("url" => "?i[category]=Images&i[usage]=Modify")

      assert_equal [ "Images" ], config.search_params["and[category]"]
      assert_equal [ "Modify" ], config.search_params["and[usage]"]
    end

    test "omits pagination facet and unknown query keys" do
      config = HarvestConfig.new(
        "url" => "https://digitalnz.org/records?i[category]=Images&page=2&per_page=20&utf8=%E2%9C%93&facets=decade&facets_per_page=100&fields=verbose&sort=date"
      )
      params = config.search_params

      assert_equal [ "Images" ], params["and[category]"]
      %w[page per_page utf8 facets facets_per_page fields sort].each do |key|
        assert_nil params[key], key
      end
    end

    test "drops blank values and keeps text and or filters" do
      config = HarvestConfig.new(
        "url" => "https://api.digitalnz.org/v3/records.json?text=wellington&or[decade][]=1950&i[usage]=",
        "params" => { "i[content_partner]" => "" }
      )
      params = config.search_params

      assert_equal [ "wellington" ], params["text"]
      assert_equal [ "1950" ], params["or[decade]"]
      assert_nil params["and[usage]"]
      assert_nil params["and[content_partner]"]
    end

    test "prefilters exact exclude values as without params and skips globs" do
      config = HarvestConfig.new(
        "params" => { "i[category]" => "Images" },
        "exclude" => {
          "subjects" => [ "Portraits", "*colour*" ],
          "partners" => [ "The British Library", "*University*" ],
          "types" => [ "Map", "*portrait*" ]
        }
      )

      assert_equal [ "Portraits" ], config.search_params["without[subject]"]
      assert_equal [ "The British Library" ], config.search_params["without[content_partner]"]
      assert_equal [ "Map" ], config.search_params["without[dc_type]"]
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
      assert config.allowed_partner?(nil)
      assert_not config.allowed_partner?("University of Otago")
    end

    test "excludes records by title, description, subject, and type patterns" do
      config = HarvestConfig.new(
        "exclude" => {
          "subjects" => [ "Portraits", "*colour*" ],
          "types" => [ "Map", "*portrait*" ],
          "title" => [ "*portrait*", "*colour*" ],
          "description" => [ "*colour*" ]
        }
      )

      assert config.excluded_record?(title: "Portrait of Jane", subject: [], dc_type: [])
      assert config.excluded_record?(title: "Street", description: "Hand coloured print", subject: [], dc_type: [])
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

    test "app YAML searches Images with Modify and Use commercially" do
      params = HarvestConfig.current.search_params

      assert_equal [ "Images" ], params["and[category]"]
      assert_nil params["and[content_partner]"]
      assert_includes params["and[usage]"], "Modify"
      assert_includes params["and[usage]"], "Use commercially"
      assert_includes params["without[subject]"], "Portraits"
      assert_includes params["without[content_partner]"], "The British Library"
      assert_includes params["without[dc_type]"], "Map"
      assert_not_includes params["without[subject]"], "*colour*"
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
      assert config.excluded_record?(title: "Street", subject: [ "studio portraits" ], dc_type: [])
      assert config.excluded_record?(title: "Hand coloured postcard", subject: [], dc_type: [])
    end
  end
end
