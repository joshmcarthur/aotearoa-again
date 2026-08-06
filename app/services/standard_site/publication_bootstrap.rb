module StandardSite
  class PublicationBootstrap
    SITE_NAME = "Aotearoa, Again".freeze
    SITE_DESCRIPTION = "Daily photographs from the Alexander Turnbull Library, seen again in colour.".freeze

    def self.call(client: Bluesky::Client.new, icon_path: Rails.root.join("public/icon.png"))
      new(client: client, icon_path: icon_path).call
    end

    def initialize(client:, icon_path:)
      @client = client
      @icon_path = icon_path
    end

    def call
      icon_blob = upload_icon
      record = {
        "$type" => "site.standard.publication",
        "url" => site_url,
        "name" => SITE_NAME,
        "description" => SITE_DESCRIPTION,
        "icon" => icon_blob,
        "basicTheme" => basic_theme,
        "preferences" => {
          "showInDiscover" => true
        }
      }

      @client.create_record(collection: "site.standard.publication", record: record)
    end

    private

    def site_url
      "#{AppConfig.protocol}://#{AppConfig.app_host}"
    end

    def upload_icon
      raise Bluesky::Client::Error, "Publication icon missing at #{@icon_path}" unless @icon_path.exist?

      bytes = @icon_path.read
      @client.upload_blob(bytes, content_type: "image/png")
    end

    def basic_theme
      {
        "$type" => "site.standard.theme.basic",
        "background" => rgb(243, 239, 230),
        "foreground" => rgb(26, 26, 26),
        "accent" => rgb(26, 26, 26),
        "accentForeground" => rgb(243, 239, 230)
      }
    end

    def rgb(r, g, b)
      {
        "$type" => "site.standard.theme.color#rgb",
        "r" => r,
        "g" => g,
        "b" => b
      }
    end
  end
end
