require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Wikilovesmonuments
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    config.active_job.queue_adapter = :sidekiq
    Redis.exists_returns_integer = true

    Time.zone = "Europe/Rome"
    Groupdate.week_start = :monday

    config.filter_parameters << :latitude
    config.filter_parameters << :longitude
    
    Raven.configure do |config|
      config.dsn = ENV["DSN"]
      config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
    end
    
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
