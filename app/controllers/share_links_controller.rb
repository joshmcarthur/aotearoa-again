class ShareLinksController < ApplicationController
  def show
    share_link = ShareLink.find_by!(code: params[:code])
    edition = share_link.variant.edition

    if edition&.state == "published"
      redirect_to edition_url(edition), status: :found
    else
      render "editions/not_published", status: :not_found
    end
  end
end
