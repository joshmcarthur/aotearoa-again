module Admin
  class EditionsController < BaseController
    def index
      @editions = Edition.includes(variant: { candidate: :source_item }).order(publish_on: :desc)
      @runway_days = Edition.approved_runway_days
    end
  end
end
