module Digitalnz
  class RandomSelector
    # Modify: colourisation allowed. Use commercially: NatLib free-download /
    # Meta-upload-eligible ATL subset (see docs/natlib-social-media.md).
    # Use "and[usage]" (not "and[usage][]") so Faraday NestedParamsEncoder
    # emits and[usage][]=Modify&and[usage][]=Use+commercially.
    BASE_FILTERS = {
      "and[content_partner][]" => "Alexander Turnbull Library",
      "and[category][]" => "Images",
      "and[usage]" => [ "Modify", "Use commercially" ]
    }.freeze

    PER_PAGE = 20
    MAX_ATTEMPTS = 12
    # DigitalNZ returns 400 for anonymous users beyond page 100.
    ANONYMOUS_MAX_PAGE = 100
    AUTHENTICATED_MAX_PAGE = 500

    def initialize(client: Client.new, exclude_ids: nil, authenticated: AppConfig.digitalnz_api_key.present?)
      @client = client
      @exclude_ids = Set.new((exclude_ids || SourceItem.pluck(:digitalnz_id)).map(&:to_s))
      @authenticated = authenticated
    end

    def call
      MAX_ATTEMPTS.times do
        decade = pick_decade
        next unless decade

        page = pick_page(decade)
        next unless page

        records = fetch_page(decade, page)
        record = records.find { |r| acceptable_new?(r) }
        return record if record
      rescue Client::Error
        next
      end
      nil
    end

    private

    def pick_decade
      data = @client.search(BASE_FILTERS.merge(facets: "decade", facets_per_page: 100, per_page: 0))
      facets = data.dig("search", "facets", "decade") || data.dig("facets", "decade") || {}
      values = normalize_facet_values(facets)
      return nil if values.empty?

      total = values.sum { |v| v[:count] }
      target = rand(total)
      running = 0
      values.each do |v|
        running += v[:count]
        return v[:name] if target < running
      end
      values.last[:name]
    end

    # DigitalNZ returns facets as { "1950" => 20803, ... }. Older docs/examples
    # sometimes show [{ "name" => "1950", "count" => 20803 }, ...].
    def normalize_facet_values(facets)
      case facets
      when Hash
        facets.filter_map do |name, count|
          count = count.to_i
          next if name.blank? || count <= 0

          { name: name.to_s, count: count }
        end
      when Array
        facets.filter_map do |facet|
          next unless facet.respond_to?(:[])

          name = facet["name"] || facet[:name]
          count = (facet["count"] || facet[:count]).to_i
          next if name.blank? || count <= 0

          { name: name.to_s, count: count }
        end
      else
        []
      end
    end

    def pick_page(decade)
      data = @client.search(BASE_FILTERS.merge("and[decade][]" => decade, per_page: PER_PAGE, page: 1))
      result_count = (data.dig("search", "result_count") || data["result_count"]).to_i
      return nil if result_count <= 0

      max_page = [ (result_count.to_f / PER_PAGE).ceil, 1 ].max
      max_page = [ max_page, page_ceiling ].min
      rand(1..max_page)
    end

    def page_ceiling
      @authenticated ? AUTHENTICATED_MAX_PAGE : ANONYMOUS_MAX_PAGE
    end

    def fetch_page(decade, page)
      data = @client.search(BASE_FILTERS.merge("and[decade][]" => decade, per_page: PER_PAGE, page: page))
      Array(data.dig("search", "results") || data["results"])
    end

    def acceptable_new?(record)
      id = record["id"] || record[:id]
      return false if id.blank? || @exclude_ids.include?(id.to_s)
      return false unless RightsFilter.acceptable?(record)

      true
    end
  end
end
