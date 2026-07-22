module Admin
  class BaseController < ApplicationController
    before_action :authenticate_admin
    layout "admin"

    private

    def authenticate_admin
      authenticate_or_request_with_http_basic("Aotearoa Again Admin") do |username, password|
        ActiveSupport::SecurityUtils.secure_compare(username.to_s, AppConfig.admin_username.to_s) &&
          ActiveSupport::SecurityUtils.secure_compare(password.to_s, AppConfig.admin_password.to_s)
      end
    end
  end
end
