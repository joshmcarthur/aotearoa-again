class EditionImagesController < ApplicationController
  # Stable public media for published artifacts (email, Instagram, Atom, OG).
  # Signed blob URLs expire and break mail clients and Meta fetchers.
  # Allowed for scheduled editions too — channel jobs deliver before publish!.

  def share
    serve_attachment(find_edition.variant.distribution_image, "share.jpg", "image/jpeg")
  end

  def share_video
    serve_attachment(find_edition.variant.share_video, "share.mp4", "video/mp4")
  end

  def composite
    serve_attachment(find_edition.variant.archive_image, "composite.jpg", "image/jpeg")
  end

  private

  def find_edition
    edition = Edition.find_by!(publish_on: params[:publish_on])
    unless edition.state.in?(%w[scheduled published])
      raise ActiveRecord::RecordNotFound
    end

    edition
  end

  def serve_attachment(attachment, filename, default_type)
    raise ActiveRecord::RecordNotFound unless attachment.attached?

    expires_in 1.day, public: true
    send_data attachment.download,
      type: attachment.content_type.presence || default_type,
      disposition: "inline",
      filename: filename
  end
end
