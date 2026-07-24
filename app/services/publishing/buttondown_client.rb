require "faraday"
require "json"

module Publishing
  class ButtondownClient
    BASE_URL = "https://api.buttondown.com/v1".freeze

    class Error < StandardError; end

    def initialize(api_key: AppConfig.buttondown_api_key, http: nil)
      @api_key = api_key
      @http = http || Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    # Creates an email draft, then publishes it immediately (no UI step).
    def create_and_send(subject:, body:)
      # Paths must be relative (no leading slash) so Faraday keeps BASE_URL's /v1.
      create_response = @http.post("emails") do |req|
        req.headers["Authorization"] = "Token #{@api_key}"
        req.body = {
          subject: subject,
          body: body,
          status: "draft"
        }
      end
      payload = JSON.parse(create_response.body)
      email_id = payload.fetch("id")

      @http.post("emails/#{email_id}/publish") do |req|
        req.headers["Authorization"] = "Token #{@api_key}"
        req.body = {}
      end

      payload
    rescue Faraday::Error => e
      raise Error, "Buttondown request failed: #{e.message}"
    end
  end
end
