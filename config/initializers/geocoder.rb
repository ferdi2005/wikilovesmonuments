Geocoder.configure(lookup: :mapbox, api_key: ENV['MAPBOX_SECRET'], mapbox: {dataset: "mapbox.places-permanent"}, units: :km, cache: Redis.new)
