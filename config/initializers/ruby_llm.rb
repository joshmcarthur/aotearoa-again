RubyLLM.configure do |config|
  config.openrouter_api_key = AppConfig.openrouter_api_key
  config.openrouter_app_name = "Aotearoa, Again"
  config.openrouter_app_url = "#{AppConfig.protocol}://#{AppConfig.app_host}"
end
