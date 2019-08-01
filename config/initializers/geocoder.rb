Geocoder.configure(lookup: :mapbox, api_key: ENV['MAPBOX_SECRET'], cache: Redis.new)
