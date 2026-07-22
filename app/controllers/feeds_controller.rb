class FeedsController < ApplicationController
  def show
    @editions = Edition.published.order(publish_on: :desc).limit(50)
    response.headers["Content-Type"] = "application/atom+xml; charset=utf-8"
    render layout: false
  end
end
