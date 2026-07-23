module Admin
  class EditionsController < BaseController
    def index
      @editions = Edition.includes(variant: { candidate: :source_item }).order(publish_on: :desc)
      @runway_days = Edition.approved_runway_days
    end

    def show
      @edition = Edition
        .includes(
          variant: [
            :model,
            :share_link,
            { colourised_image_attachment: :blob },
            { composite_image_attachment: :blob },
            { share_image_attachment: :blob },
            { candidate: [ :source_item, { original_image_attachment: :blob } ] }
          ]
        )
        .find_by!(publish_on: params[:id])
    end
  end
end
