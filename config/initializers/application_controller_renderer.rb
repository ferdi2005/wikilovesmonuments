# Be sure to restart your server when you modify this file.

ActiveSupport::Reloader.to_prepare do
    ApplicationController.renderer.defaults.merge!(
    http_host: Rails.application.routes.default_url_options[:host],
    https: true
    )
end