module Admin
  module CandidatesHelper
    def candidate_review_status_classes(status)
      case status
      when :needs_review
        "border-amber-300 bg-amber-50 text-amber-900"
      when :scheduled
        "border-emerald-300 bg-emerald-50 text-emerald-900"
      when :published
        "border-sky-300 bg-sky-50 text-sky-900"
      when :failed
        "border-red-300 bg-red-50 text-red-900"
      when :rejected
        "border-stone-300 bg-stone-100 text-stone-700"
      else
        _never = status
        raise "Unhandled review status: #{_never.inspect}"
      end
    end
  end
end
