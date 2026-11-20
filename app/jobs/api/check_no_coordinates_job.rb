# frozen_string_literal: true

module Api
  class CheckNoCoordinatesJob < ApplicationJob
    queue_as :default

    def perform(*_args)
      Monument.where("latitude IS NULL AND (photos_count > 0 OR with_photos = ?)", true).find_each do |monument|
        metadata = {}

        request = WikimediaApi.get(
          "https://commons.wikimedia.org/w/api.php",
          query: {
            action: :query,
            prop: :imageinfo,
            iiprop: "metadata",
            iilimit: 500,
            generator: :search,
            gsrsearch: %("#{monument.wlmid}"),
            gsrwhat: :text,
            gsrnamespace: 6,
            gsrlimit: 500,
            format: :json
          }
        )
        metadata.merge!(request.dig("query", "pages").to_h) if request.is_a?(Hash)

        while request.is_a?(Hash) && request.dig("continue", "gsrcontinue").present?
          request = WikimediaApi.get(
            "https://commons.wikimedia.org/w/api.php",
            query: {
              action: :query,
              prop: :imageinfo,
              iiprop: "metadata",
              iilimit: 500,
              generator: :search,
              gsrsearch: %("#{monument.wlmid}"),
              gsrcontinue: request.dig("continue", "gsrcontinue"),
              gsrwhat: :text,
              gsrnamespace: 6,
              gsrlimit: 500,
              format: :json
            }
          )
          metadata.merge!(request.dig("query", "pages").to_h) if request.is_a?(Hash)
        end

        unless monument.commons.blank?
          cat_request = WikimediaApi.get(
            "https://commons.wikimedia.org/w/api.php",
            query: {
              action: :query,
              prop: :imageinfo,
              iiprop: "metadata",
              iilimit: 500,
              generator: :categorymembers,
              gcmtitle: "Category:#{monument.commons}",
              gcmnamespace: 6,
              gcmlimit: 500,
              format: :json
            }
          )
          metadata.merge!(cat_request.dig("query", "pages").to_h) if cat_request.is_a?(Hash)

          while cat_request.is_a?(Hash) && cat_request.dig("continue", "gcmcontinue").present?
            cat_request = WikimediaApi.get(
              "https://commons.wikimedia.org/w/api.php",
              query: {
                action: :query,
                prop: :imageinfo,
                iiprop: "metadata",
                iilimit: 500,
                generator: :categorymembers,
                gcmtitle: "Category:#{monument.commons}",
                gcmcontinue: cat_request.dig("continue", "gcmcontinue"),
                gcmnamespace: 6,
                gcmlimit: 500,
                format: :json
              }
            )
            metadata.merge!(cat_request.dig("query", "pages").to_h) if cat_request.is_a?(Hash)
          end
        end

        unless monument.image.blank?
          decoded_image = begin
            URI.decode_www_form_component(monument.image)
          rescue ArgumentError
            monument.image
          end
          image_request = WikimediaApi.get(
            "https://commons.wikimedia.org/w/api.php",
            query: {
              action: :query,
              prop: :imageinfo,
              iiprop: "metadata",
              titles: "File:#{decoded_image}",
              format: :json
            }
          )
          metadata.merge!(image_request.dig("query", "pages").to_h) if image_request.is_a?(Hash)
        end

        next if metadata.blank?

        coordinates = []
        metadata.each do |page_key, image|
          next if page_key.to_s == "-1" || !image.is_a?(Hash) || image["ns"] != 6

          image_meta = image.dig("imageinfo", 0, "metadata")
          next unless image_meta.is_a?(Array)

          lat_val = image_meta.find { |h| h["name"] == "GPSLatitude" }&.dig("value")
          lon_val = image_meta.find { |h| h["name"] == "GPSLongitude" }&.dig("value")
          next if lat_val.nil? || lon_val.nil?

          latitude = lat_val.to_d
          longitude = lon_val.to_d
          coordinates << [latitude, longitude] if latitude != 0 && longitude != 0
        end

        ::CheckNoCoordinatesJob.update_monument_coordinates!(monument, coordinates)
      end
    end
  end
end
