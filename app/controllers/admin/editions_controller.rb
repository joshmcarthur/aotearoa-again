module Admin
  class EditionsController < BaseController
    before_action :set_edition, only: %i[show regenerate]

    def index
      @editions = Edition.includes(variant: { candidate: :source_item }).order(publish_on: :desc)
      @runway_days = Edition.approved_runway_days
    end

    def show
    end

    def regenerate
      variant_id = @edition.variant_id
      ComposeShareImageJob.perform_later(variant_id)
      ComposeShareVideoJob.perform_later(variant_id)
      redirect_to admin_edition_path(@edition), notice: "Share assets queued"
    end

    private

    def set_edition
      @edition = Edition
        .includes(
          variant: [
            :model,
            :share_link,
            { colourised_image_attachment: :blob },
            { composite_image_attachment: :blob },
            { share_image_attachment: :blob },
            { share_video_attachment: :blob },
            { candidate: [ :source_item, { original_image_attachment: :blob } ] }
          ]
        )
        .find_by!(publish_on: params[:id])
    end
  end
end
