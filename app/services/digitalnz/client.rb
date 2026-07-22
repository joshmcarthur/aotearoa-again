require "faraday"
require "json"

module Digitalnz
  class Client
    BASE_URL = "https://api.digitalnz.org".freeze

    class Error < StandardError; end

    # DigitalNZ public search works without a key. An optional key raises the
    # shared unauthenticated rate limit; pass it via Authentication-Token.
    def initialize(api_key: AppConfig.digitalnz_api_key, http: nil)
      @api_key = api_key.presence
      @http = http || Faraday.new(url: BASE_URL) do |f|
        f.request :url_encoded
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def search(params = {})
      get("/v3/records.json", params)
    end

    def get_record(id, fields: "verbose")
      get("/v3/records/#{id}.json", { fields: fields })
    end

    private

    def get(path, params)
      response = @http.get(path) do |req|
        req.params = params
        req.headers["Authentication-Token"] = @api_key if @api_key
      end
      JSON.parse(response.body)
    rescue Faraday::Error => e
      raise Error, "DigitalNZ request failed: #{e.message}"
    end
  end
end
