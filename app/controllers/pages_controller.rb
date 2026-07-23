class PagesController < ApplicationController
  def about
  end

  def subscribe
    url = AppConfig.buttondown_subscribe_url.presence
    if url
      redirect_to url, allow_other_host: true
    else
      render :subscribe
    end
  end
end
