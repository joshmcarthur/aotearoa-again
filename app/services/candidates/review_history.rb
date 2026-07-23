module Candidates
  Event = Data.define(:at, :kind, :label, :detail)

  class ReviewHistory
    STATUSES = %i[needs_review scheduled published failed rejected].freeze

    def initialize(candidate)
      @candidate = candidate
    end

    def status
      return :rejected if @candidate.status == "rejected"

      edition = current_edition
      return :needs_review unless edition

      case edition.state
      when "scheduled" then :scheduled
      when "published" then :published
      when "failed" then :failed
      else
        raise "Unknown edition state: #{edition.state.inspect}"
      end
    end

    def status_label
      {
        needs_review: "Needs review",
        scheduled: "Scheduled",
        published: "Published",
        failed: "Publish failed",
        rejected: "Rejected"
      }.fetch(status)
    end

    def summary
      parts = []
      variant_count = @candidate.variants.size
      parts << (variant_count == 1 ? "1 variant" : "#{variant_count} variants") if variant_count.positive?

      case status
      when :needs_review
        parts << "not reviewed"
      when :scheduled
        parts << "scheduled for #{current_edition.publish_on}"
      when :published
        parts << "published #{current_edition.publish_on}"
      when :failed
        parts << "publish failed"
      when :rejected
        parts << "rejected"
      else
        _never = status
        raise "Unhandled review status: #{_never.inspect}"
      end

      parts.join(" · ")
    end

    def events
      collected = []
      collected << Event.new(
        at: @candidate.created_at,
        kind: :created,
        label: "Harvested",
        detail: nil
      )

      @candidate.variants.sort_by(&:created_at).each do |variant|
        detail = variant.model.name
        detail += " (chosen)" if variant.chosen?
        collected << Event.new(
          at: variant.created_at,
          kind: :colourised,
          label: "Colourised",
          detail: detail
        )
      end

      if (edition = current_edition)
        collected << Event.new(
          at: edition.created_at,
          kind: :approved,
          label: "Approved",
          detail: "Scheduled for #{edition.publish_on} · #{edition.variant.model.name}"
        )

        if edition.state == "published" && edition.published_at.present?
          collected << Event.new(
            at: edition.published_at,
            kind: :published,
            label: "Published",
            detail: edition.publish_on.to_s
          )
        end

        if edition.state == "failed"
          collected << Event.new(
            at: edition.updated_at,
            kind: :failed,
            label: "Publish failed",
            detail: edition.admin_note.presence
          )
        end
      end

      if @candidate.status == "rejected"
        collected << Event.new(
          at: @candidate.updated_at,
          kind: :rejected,
          label: "Rejected",
          detail: @candidate.rejection_reason.presence
        )
      end

      collected.sort_by(&:at)
    end

    private

    def current_edition
      @current_edition ||= @candidate.editions.max_by(&:created_at)
    end
  end
end
