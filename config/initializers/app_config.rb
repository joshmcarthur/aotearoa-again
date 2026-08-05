# Central access to app secrets and settings from environment-specific
# Rails credentials:
#
#   bin/rails credentials:edit --environment development
#   bin/rails credentials:edit --environment test
#   bin/rails credentials:edit --environment production
#
# Keys live in config/credentials/<env>.key (gitignored except test.key).
# Production deploy provides RAILS_MASTER_KEY (= production.key contents).
#
# Expected shape:
#
#   digitalnz:                 # optional — public API works without a key
#     api_key: ...             # only if you need a higher rate limit
#   openrouter:
#     api_key: ...
#   buttondown:
#     api_key: ...
#     subscribe_url: https://buttondown.com/...
#   meta:                      # optional — Instagram/Facebook deliveries skipped when blank
#     page_access_token: ...   # Page access token from /me/accounts
#     page_id: ...             # enables Facebook Page posting
#     instagram_user_id: ...   # enables Instagram Content Publishing
#   youtube:                   # optional — YouTube Shorts delivery skipped when blank
#     client_id: ...
#     client_secret: ...
#     refresh_token: ...       # offline OAuth token for the target channel
#                              # upload metadata (category, AI disclosure, location)
#                              # lives on AppConfig.youtube_upload_defaults — not credentials
#   bluesky:                   # optional — Bluesky delivery skipped when blank
#     handle: aotearoa-again.example
#     app_password: xxxx-xxxx-xxxx-xxxx
#     pds_host: bsky.social    # optional
#     publication_uri: at://did:plc:.../site.standard.publication/...
#     publication_cid: bafyrei...
#   admin:
#     username: admin
#     password: ...
#     alert_email: you@example.com
#   app:
#     host: aotearoa-again.example
#     harvest_pipeline_target: 3
#     instagram_url: https://www.instagram.com/...
#     facebook_url: https://www.facebook.com/...
#     youtube_url: https://www.youtube.com/@...
#     bluesky_url: https://bsky.app/profile/aotearoa-again.example
#   smtp:
#     address: ...
#     port: 587
#     user_name: ...
#     password: ...
#     domain: ...
#
module AppConfig
  module_function

  YOUTUBE_UPLOAD_DEFAULTS = {
    snippet: { categoryId: "27" }, # Education
    status: {
      privacyStatus: "public",
      selfDeclaredMadeForKids: false,
      containsSyntheticMedia: true
    },
    recordingDetails: {
      locationDescription: "New Zealand"
    }
  }.freeze

  def digitalnz_api_key = dig(:digitalnz, :api_key)

  def openrouter_api_key = dig(:openrouter, :api_key)

  def buttondown_api_key = required(:buttondown, :api_key)

  def buttondown_subscribe_url = dig(:buttondown, :subscribe_url)

  def meta_page_access_token = dig(:meta, :page_access_token)

  def meta_page_id = dig(:meta, :page_id)

  def meta_instagram_user_id = dig(:meta, :instagram_user_id)

  def instagram_configured?
    meta_page_access_token.present? && meta_instagram_user_id.present?
  end

  def facebook_configured?
    meta_page_access_token.present? && meta_page_id.present?
  end

  def youtube_client_id = dig(:youtube, :client_id)

  def youtube_client_secret = dig(:youtube, :client_secret)

  def youtube_refresh_token = dig(:youtube, :refresh_token)

  def youtube_upload_defaults = YOUTUBE_UPLOAD_DEFAULTS

  def youtube_configured?
    youtube_client_id.present? && youtube_client_secret.present? && youtube_refresh_token.present?
  end

  def bluesky_handle = dig(:bluesky, :handle)

  def bluesky_app_password = dig(:bluesky, :app_password)

  def bluesky_pds_host = dig(:bluesky, :pds_host)

  def bluesky_publication_uri = dig(:bluesky, :publication_uri)

  def bluesky_publication_cid = dig(:bluesky, :publication_cid)

  def bluesky_configured?
    bluesky_handle.present? &&
      bluesky_app_password.present? &&
      bluesky_publication_uri.present? &&
      bluesky_publication_cid.present?
  end

  def admin_username = dig(:admin, :username).presence || "admin"

  def admin_password = required(:admin, :password)

  def admin_alert_email = dig(:admin, :alert_email).presence || admin_username

  def app_host = dig(:app, :host).presence || "localhost:3000"

  def instagram_url = dig(:app, :instagram_url)

  def facebook_url = dig(:app, :facebook_url)

  def youtube_url = dig(:app, :youtube_url)

  def bluesky_url = dig(:app, :bluesky_url)

  def harvest_pipeline_target = Integer(dig(:app, :harvest_pipeline_target).presence || 3)

  def smtp = dig(:smtp) || {}

  def protocol = app_host.to_s.include?("localhost") ? "http" : "https"

  def dig(*keys)
    Rails.application.credentials.dig(*keys)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def required(*keys)
    value = dig(*keys)
    raise KeyError, "Missing credentials #{keys.join(".")}. Run bin/rails credentials:edit --environment #{Rails.env}" if value.blank?

    value
  end
end
