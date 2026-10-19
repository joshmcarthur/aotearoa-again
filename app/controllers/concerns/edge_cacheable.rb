# Public pages are cached at the edge (Cloudflare) until the next edition
# publishes, when the homepage, archive, feed, and adjacent-edition links change.
# Browsers get a short max-age so they never hold a page past that boundary.
module EdgeCacheable
  extend ActiveSupport::Concern

  BROWSER_MAX_AGE = 5.minutes
  BRIEF_MAX_AGE = 1.minute
  STALE_IF_ERROR = 1.day

  included do
    # Cloudflare will not cache responses that set a cookie.
    before_action { request.session_options[:skip] = true }
    before_action :cache_until_next_edition
  end

  private

  def cache_until_next_edition
    ttl = (Edition.next_publish_at - Time.current).ceil
    expires_in [ BROWSER_MAX_AGE.to_i, ttl ].min, public: true, stale_if_error: STALE_IF_ERROR, "s-maxage": ttl
  end

  # For "not ready yet" responses that should pick up a publish promptly.
  def cache_briefly
    expires_in BRIEF_MAX_AGE, public: true, "s-maxage": BRIEF_MAX_AGE.to_i
  end
end
