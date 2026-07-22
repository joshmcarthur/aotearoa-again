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

    # Creates a draft only — never queues a send. Promote via Buttondown UI
    # or a later PATCH to status "about_to_send" / "scheduled".
    def create_draft(subject:, body:)
      # Path must be relative (no leading slash) so Faraday keeps BASE_URL's /v1.
      response = @http.post("emails") do |req|
        req.headers["Authorization"] = "Token #{@api_key}"
        req.body = {
          subject: subject,
          body: body,
          status: "draft"
        }
      end
      JSON.parse(response.body)
    rescue Faraday::Error => e
      raise Error, "Buttondown request failed: #{e.message}"
    end
  end
end
