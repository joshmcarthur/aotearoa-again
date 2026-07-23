class EditionsController < ApplicationController
  def today
    @edition = Edition.published.find_by(publish_on: Time.zone.today) ||
               Edition.published.order(publish_on: :desc).first
    if @edition
      @copy = Editions::Copy.new(@edition.source_item)
      render :show
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
  end
end
