module Publishing
  class FinalizeEdition
    def self.enqueue_if_ready(edition_id)
      edition = Edition.find_by(id: edition_id)
      return unless edition&.state == "published"
      return unless edition.deliveries_terminal?

      FinalizeEditionPublishJob.perform_later(edition_id)
    end
  end
end
