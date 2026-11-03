class RefreshRubyLlmModelsJob < ApplicationJob
  queue_as :default

  def perform
    RubyLLM.models.refresh
  end
end
