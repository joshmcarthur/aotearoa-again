module Digitalnz
  class RandomSelector
    # Search params come from config/digitalnz.yml (url, params, exact exclude prefilters).
    # Use "and[usage]" (not "and[usage][]") so Faraday NestedParamsEncoder
    # emits and[usage][]=Modify&and[usage][]=Use+commercially.

    PER_PAGE = 20
    MAX_ATTEMPTS = 12
    # DigitalNZ returns 400 for anonymous users beyond page 100.
    ANONYMOUS_MAX_PAGE = 100
    AUTHENTICATED_MAX_PAGE = 500

    def initialize(client: Client.new, exclude_ids: nil, authenticated: AppConfig.digitalnz_api_key.present?, allow_people: true)
      @client = client
      @exclude_ids = Set.new((exclude_ids || SourceItem.pluck(:digitalnz_id)).map(&:to_s))
      @authenticated = authenticated
      @allow_people = allow_people
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
        record = pick_record(records)
        return record if record
      rescue Client::RateLimited
        raise
      rescue Client::Error
        next
      end
      nil
    end

    def exclude(id)
      @exclude_ids.add(id.to_s)
    end

    def allow_people=(value)
      @allow_people = value
    end

    private

    def pick_partner
      return nil if partner_names.empty?

      partner_names.sample
    end

    def partner_names
      return @partner_names if defined?(@partner_names)

      data = @client.search(search_filters.merge(facets: "content_partner", facets_per_page: 150, per_page: 0))
      facets = data.dig("search", "facets", "content_partner") || data.dig("facets", "content_partner") || {}
      @partner_names = normalize_facet_values(facets)
        .select { |value| RightsFilter.allowed_partner?(value[:name]) }
        .map { |value| value[:name] }
    end

    def pick_decade(partner)
      values = decade_values(partner)
      return nil if values.empty?

      total = values.sum { |value| value[:count] }
      target = rand(total)
      running = 0
      values.each do |value|
        running += value[:count]
        return value[:name] if target < running
      end
      values.last[:name]
    end

    def decade_values(partner)
      @decade_values ||= {}
      return @decade_values[partner] if @decade_values.key?(partner)

      data = @client.search(partner_filters(partner).merge(facets: "decade", facets_per_page: 100, per_page: 0))
      facets = data.dig("search", "facets", "decade") || data.dig("facets", "decade") || {}
      @decade_values[partner] = normalize_facet_values(facets)
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
      result_count = result_count_for(partner, decade)
      return nil if result_count <= 0

      max_page = [ (result_count.to_f / PER_PAGE).ceil, 1 ].max
      max_page = [ max_page, page_ceiling ].min
      rand(1..max_page)
    end

    def result_count_for(partner, decade)
      @result_counts ||= {}
      key = [ partner, decade ]
      return @result_counts[key] if @result_counts.key?(key)

      data = @client.search(partner_filters(partner).merge("and[decade][]" => decade, per_page: PER_PAGE, page: 1))
      @result_counts[key] = (data.dig("search", "result_count") || data["result_count"]).to_i
    end

    def page_ceiling
      @authenticated ? AUTHENTICATED_MAX_PAGE : ANONYMOUS_MAX_PAGE
    end

    def fetch_page(partner, decade, page)
      data = @client.search(partner_filters(partner).merge("and[decade][]" => decade, per_page: PER_PAGE, page: page))
      Array(data.dig("search", "results") || data["results"])
    end

    def search_filters
      HarvestConfig.current.search_params
    end

    def partner_filters(partner)
      search_filters.merge("and[content_partner]" => [ partner ])
    end

    def pick_record(records)
      acceptable = records.select { |record| acceptable_new?(record) }
      acceptable = acceptable.reject { |record| people_record?(record) } unless @allow_people
      preferred = acceptable.reject { |record| people_record?(record) }
      (preferred.presence || acceptable).sample
    end

    def people_record?(record)
      HarvestConfig.current.people_record?(record)
    end

    def acceptable_new?(record)
      id = record["id"] || record[:id]
      return false if id.blank? || @exclude_ids.include?(id.to_s)
      return false unless RightsFilter.acceptable?(record)

      true
    end
  end
end
