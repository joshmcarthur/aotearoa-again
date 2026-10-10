module Digitalnz
  class RandomSelector
    # Modify: colourisation allowed. Use commercially: remix / social-upload
    # eligible subset (see docs/natlib-social-media.md).
    # Use "and[usage]" / "without[subject]" (not the [] form) so Faraday
    # NestedParamsEncoder emits and[usage][]=Modify&and[usage][]=Use+commercially.
    BASE_FILTERS = {
      "and[category][]" => "Images",
      "and[usage]" => [ "Modify", "Use commercially" ],
      "without[subject]" => [
        "Portraits",
        "portraits",
        "studio portraits",
        "Group portraits",
        "people"
      ]
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
        partner = pick_partner
        next unless partner

        decade = pick_decade(partner)
        next unless decade

        page = pick_page(partner, decade)
        next unless page

        records = fetch_page(partner, decade, page)
        record = records.find { |r| acceptable_new?(r) }
        return record if record
      rescue Client::Error
        next
      end
      nil
    end

    private

    def pick_partner
      data = @client.search(BASE_FILTERS.merge(facets: "content_partner", facets_per_page: 150, per_page: 0))
      facets = data.dig("search", "facets", "content_partner") || data.dig("facets", "content_partner") || {}
      partners = normalize_facet_values(facets).select { |value| PartnerFilter.allowed?(value[:name]) }
      return nil if partners.empty?

      partners.sample[:name]
    end

    def pick_decade(partner)
      data = @client.search(partner_filters(partner).merge(facets: "decade", facets_per_page: 100, per_page: 0))
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

    def pick_page(partner, decade)
      data = @client.search(partner_filters(partner).merge("and[decade][]" => decade, per_page: PER_PAGE, page: 1))
      result_count = (data.dig("search", "result_count") || data["result_count"]).to_i
      return nil if result_count <= 0

      max_page = [ (result_count.to_f / PER_PAGE).ceil, 1 ].max
      max_page = [ max_page, page_ceiling ].min
      rand(1..max_page)
    end

    def page_ceiling
      @authenticated ? AUTHENTICATED_MAX_PAGE : ANONYMOUS_MAX_PAGE
    end

    def fetch_page(partner, decade, page)
      data = @client.search(partner_filters(partner).merge("and[decade][]" => decade, per_page: PER_PAGE, page: page))
      Array(data.dig("search", "results") || data["results"])
    end

    def partner_filters(partner)
      BASE_FILTERS.merge("and[content_partner][]" => partner)
    end

    def acceptable_new?(record)
      id = record["id"] || record[:id]
      return false if id.blank? || @exclude_ids.include?(id.to_s)
      return false unless RecordFilter.acceptable?(record)

      true
    end
  end
end
