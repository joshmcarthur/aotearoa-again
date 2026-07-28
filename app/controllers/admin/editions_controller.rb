module Admin
  class EditionsController < BaseController
    before_action :set_edition, only: %i[show regenerate_share_video regenerate_variant]

    def index
      @editions = Edition.includes(variant: { candidate: :source_item }).order(publish_on: :desc)
      @runway_days = Edition.approved_runway_days
    end

    def show
    end

    def regenerate_share_video
      ComposeShareVideoJob.perform_later(@edition.variant_id)
      redirect_to admin_edition_path(@edition), notice: "Share video queued"
    end

    def regenerate_variant
      model_id = params[:model_id]
      if model_id.present?
        RegenerateVariantJob.perform_later(@edition.variant_id, model_id: model_id)
      else
        RegenerateVariantJob.perform_later(@edition.variant_id)
      end
      redirect_to admin_edition_path(@edition), notice: "Variant colourisation queued"
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
