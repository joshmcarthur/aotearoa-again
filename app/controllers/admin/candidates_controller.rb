module Admin
  class CandidatesController < BaseController
    before_action :set_candidate, only: %i[show approve reject regenerate queue_colourise]

    def index
      @runway_days = Edition.approved_runway_days
      @clearance_candidates = Candidate.pending_review
        .includes(:source_item)
        .with_attached_original_image
        .order(created_at: :desc)
      @candidates = Candidate.awaiting_approval
        .includes(:source_item, variants: [ :model, :edition ], editions: { variant: :model })
        .order(created_at: :desc)
      @pending = Candidate.where(status: %w[pending_colour colouring]).count
    end

    def show
      @variants = @candidate.variants.includes(:model, :edition)
      @review_history = @candidate.review_history
    end

    def approve
      variant = @candidate.variants.find(params.require(:variant_id))
      edition = Editions::Approver.new(@candidate, variant: variant).call
      redirect_to admin_candidates_path, notice: "Approved for #{edition.publish_on}"
    end

    def reject
      @candidate.reject!(reason: params[:reason])
      redirect_to admin_candidates_path, notice: "Candidate rejected"
    end

    def regenerate
      model_id = params[:model_id]
      ColouriseCandidateJob.perform_later(
        @candidate.id,
        model_ids: model_id.present? ? [ model_id ] : nil,
        replace: true
      )
      redirect_to admin_candidate_path(@candidate), notice: "Colourisation queued"
    end

    def queue_colourise
      if @candidate.status == "pending_review"
        @candidate.queue_colourise!
        ColouriseCandidateJob.perform_later(@candidate.id)
        redirect_to admin_candidates_path, notice: "Colourisation queued"
      else
        redirect_to admin_candidate_path(@candidate), alert: "Original is not awaiting clearance"
      end
    end

    def harvest
      HarvestCandidatesJob.perform_later
      redirect_to admin_candidates_path, notice: "Harvest queued"
    end

    private

    def set_candidate
      @candidate = Candidate.find(params[:id])
    end
  end
end
