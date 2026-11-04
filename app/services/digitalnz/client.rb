require "faraday"
require "json"

module Digitalnz
  class Client
    BASE_URL = "https://api.digitalnz.org".freeze
    USER_AGENT = "https://github.com/joshmcarthur/aotearoa-again"
    RATE_LIMIT_WAIT = 60
    MAX_RATE_LIMIT_RETRIES = 3

    class Error < StandardError; end
    class RateLimited < Error; end

    # DigitalNZ public search works without a key. An optional key raises the
    # shared unauthenticated rate limit; pass it via Authentication-Token.
    def initialize(api_key: AppConfig.digitalnz_api_key, http: nil, sleeper: ->(seconds) { sleep(seconds) })
      @api_key = api_key.presence
      @sleeper = sleeper
      @http = http || Faraday.new(url: BASE_URL) do |f|
        f.headers["User-Agent"] = USER_AGENT
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
      retries = 0

      begin
        response = @http.get(path) do |req|
          req.params = params
          req.headers["Authentication-Token"] = @api_key if @api_key
        end
        JSON.parse(response.body)
      rescue Faraday::Error => e
        if rate_limited?(e) && retries < MAX_RATE_LIMIT_RETRIES
          retries += 1
          @sleeper.call(RATE_LIMIT_WAIT)
          retry
        end

        raise request_error(e)
      end
    end

    def rate_limited?(error)
      error.response_status == 403
    end

    def request_error(error)
      message = "DigitalNZ request failed: #{error.message}"
      error_class = rate_limited?(error) ? RateLimited : Error
      error_class.new(message)
    end
  end
end
