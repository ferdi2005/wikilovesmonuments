# frozen_string_literal: true

toolforge_mode = (ENV["TOOLFORGE"].to_s.downcase == "true")

geocoder_cache = if toolforge_mode
                   redis_url = if ENV["REDIS_PASSWORD"].present?
                                 "redis://:#{ENV['REDIS_PASSWORD']}@redis:6379/0"
                               else
                                 "redis://redis.svc.tools.eqiad1.wikimedia.cloud:6379/0"
                               end
                   redis_conn = Redis.new(url: ENV["REDIS_URL"].presence || redis_url)
                   namespace = ENV["REDIS_NAMESPACE"].presence || "#{ENV['TOOL_TOOLSDB_USER'] || ENV['USER'] || 'wikilovesmonuments'}_geocoder"
                   Redis::Namespace.new(namespace, redis: redis_conn)
                 elsif ENV["REDIS_URL"].present?
                   Redis.new(url: ENV["REDIS_URL"])
                 else
                   Redis.new
                 end

Geocoder.configure(cache: geocoder_cache, lookup: :mapbox, api_key: ENV['MAPBOX_SECRET'])