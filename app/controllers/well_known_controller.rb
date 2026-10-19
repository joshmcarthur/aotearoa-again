class WellKnownController < ApplicationController
  include EdgeCacheable

  def site_standard_publication
    uri = AppConfig.bluesky_publication_uri
    return head :not_found if uri.blank?

    render plain: uri
  end
end
