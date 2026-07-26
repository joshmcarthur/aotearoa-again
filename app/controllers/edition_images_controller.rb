class EditionImagesController < ApplicationController
  # Stable public JPEGs for email, Instagram, Atom, OG, and archive (signed blob URLs expire).
  # Allowed for scheduled editions too — Orchestrator delivers before publish!.

  def share
    serve_image(find_edition, :distribution_image, "share.jpg")
  end

  def composite
    serve_image(find_edition, :archive_image, "composite.jpg")
  end

  private

  def find_edition
    edition = Edition.find_by!(publish_on: params[:publish_on])
    unless edition.state.in?(%w[scheduled published])
      raise ActiveRecord::RecordNotFound
    end

    edition
  end

  def serve_image(edition, image_method, filename)
    image = edition.variant.public_send(image_method)
    raise ActiveRecord::RecordNotFound unless image.attached?

    expires_in 1.day, public: true
    send_data image.download,
      type: image.content_type.presence || "image/jpeg",
      disposition: "inline",
      filename: filename
  end
end
