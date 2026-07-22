RubyLLM.configure do |config|
  config.openrouter_api_key = AppConfig.openrouter_api_key
  config.use_new_acts_as = true
end

Rails.application.config.to_prepare do
  unless RubyLLM::Providers::OpenRouter.ancestors.include?(RubyLlmOpenrouterImagesPatch)
    RubyLLM::Providers::OpenRouter.prepend(RubyLlmOpenrouterImagesPatch)
  end
end
