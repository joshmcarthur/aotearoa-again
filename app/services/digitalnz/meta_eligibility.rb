module Digitalnz
  # Whether a DigitalNZ ATL record may be uploaded to Meta platforms under
  # NatLib guidance (docs/natlib-social-media.md).
  class MetaEligibility
    def self.eligible?(record)
      new(record).eligible?
    end

    def initialize(record)
      @filter = RightsFilter.new(record)
    end

    def eligible?
      @filter.meta_upload_eligible?
    end
  end
end
