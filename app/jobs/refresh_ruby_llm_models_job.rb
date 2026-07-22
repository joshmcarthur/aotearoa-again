class RefreshRubyLlmModelsJob < ApplicationJob
  queue_as :default

  def perform
    Model.refresh!
  end
end
