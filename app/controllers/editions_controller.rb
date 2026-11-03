class EditionsController < ApplicationController
  include EdgeCacheable

  def today
    @edition = Edition.published.find_by(publish_on: Time.zone.today)
    if @edition
      @copy = @edition.copy
      set_adjacent_editions
      render :show
    elsif (@latest_edition = Edition.published.order(publish_on: :desc).first)
      cache_briefly
      render :unavailable, status: :not_found
    else
      cache_briefly
      render :empty
    end
  end

  def index
    @editions = Edition.published.order(publish_on: :desc)
  end

  def show
    @edition = Edition.find_by!(publish_on: params[:publish_on])
    unless @edition.state == "published"
      cache_briefly
      render :not_published, status: :not_found and return
    end

    @copy = @edition.copy
    set_adjacent_editions
  end

  private

  def set_adjacent_editions
    @previous_edition = @edition.previous_published
    @next_edition = @edition.next_published
  end
end
