# frozen_string_literal: true

toolforge_mode = (ENV["TOOLFORGE"].to_s.downcase == "true")

redis_url = if ENV["REDIS_URL"].present? && !(toolforge_mode && ENV["REDIS_URL"].include?("localhost"))
              ENV["REDIS_URL"]
            elsif toolforge_mode
              if ENV["REDIS_PASSWORD"].present?
                "redis://:#{ENV['REDIS_PASSWORD']}@redis:6379/0"
              else
                "redis://redis.svc.tools.eqiad1.wikimedia.cloud:6379/0"
              end
            else
              "redis://localhost:6379/0"
            end

redis_config = { url: redis_url }

if toolforge_mode || ENV["REDIS_NAMESPACE"].present?
  namespace = ENV["REDIS_NAMESPACE"].presence || "#{ENV['TOOL_TOOLSDB_USER'] || ENV['USER'] || 'wikilovesmonuments'}_sidekiq"
  redis_config[:namespace] = namespace unless namespace == "none"
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
  schedule_file = "config/schedule.yml"
  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end