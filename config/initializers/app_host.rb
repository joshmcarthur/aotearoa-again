if Rails.env.test?
  # System tests drive a local HTTP server; production-like hosts in test credentials use https.
  Rails.application.routes.default_url_options[:host] = "www.example.com"
  Rails.application.routes.default_url_options[:protocol] = "http"
else
  Rails.application.routes.default_url_options[:host] = AppConfig.app_host
  Rails.application.routes.default_url_options[:protocol] = AppConfig.protocol
end
