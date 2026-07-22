module Admin
  class ModelsController < BaseController
    def index
      @preferred = Model.preferred_for_colourise.order(:name)
      @image_models = Model.openrouter.image_capable.order(:name)
    end

    def toggle_preferred
      model = Model.find(params[:id])
      model.update!(preferred_for_colourise: !model.preferred_for_colourise)
      redirect_to admin_models_path, notice: "#{model.model_id} preferred=#{model.preferred_for_colourise}"
    end

    def refresh
      RefreshRubyLlmModelsJob.perform_later
      redirect_to admin_models_path, notice: "Model refresh queued"
    end
  end
end
