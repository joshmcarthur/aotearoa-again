class EditionsController < ApplicationController
  def today
    @edition = Edition.published.find_by(publish_on: Time.zone.today)
    if @edition
      @copy = Editions::Copy.new(@edition.source_item)
      set_adjacent_editions
      render :show
    elsif (@latest_edition = Edition.published.order(publish_on: :desc).first)
      render :unavailable, status: :not_found
    else
      render :empty
    end
  end

  def index
    @editions = Edition.published.order(publish_on: :desc)
  end

  def show
    @edition = Edition.find_by!(publish_on: params[:publish_on])
    unless @edition.state == "published"
      render :not_published, status: :not_found and return
    end

    @copy = Editions::Copy.new(@edition.source_item)
    set_adjacent_editions
  end

  # Stable public JPEG for email, Instagram, Atom, and OG (signed blob URLs expire).
  # Allowed for scheduled editions too — Orchestrator delivers before publish!.
  def share_image
    edition = Edition.find_by!(publish_on: params[:publish_on])
    unless edition.state.in?(%w[scheduled published])
      raise ActiveRecord::RecordNotFound
    end

    image = edition.variant.distribution_image
    raise ActiveRecord::RecordNotFound unless image.attached?

    expires_in 1.day, public: true
    send_data image.download,
      type: image.content_type.presence || "image/jpeg",
      disposition: "inline",
      filename: "share.jpg"
  end

  private

  def set_adjacent_editions
    @previous_edition = @edition.previous_published
    @next_edition = @edition.next_published
  end
end
