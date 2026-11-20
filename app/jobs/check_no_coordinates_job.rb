# frozen_string_literal: true

class CheckNoCoordinatesJob < ApplicationJob
  queue_as :default

  def self.update_monument_coordinates!(monument, coordinates)
    return if coordinates.blank?

    lats = coordinates.map(&:first)
    lons = coordinates.map(&:last)
    maxlat = lats.max&.truncate(5)
    minlat = lats.min&.truncate(5)
    maxlon = lons.max&.truncate(5)
    minlon = lons.min&.truncate(5)

    geocenter = Geocoder::Calculations.geographic_center(coordinates)
    return if geocenter[0].nan? || geocenter[1].nan?

    monument.update!(
      presumed_latitude: geocenter[0].truncate(5),
      presumed_longitude: geocenter[1].truncate(5),
      presumed_maxlat: maxlat,
      presumed_minlat: minlat,
      presumed_maxlon: maxlon,
      presumed_minlon: minlon
    )
  end

  def perform(*args)
    if WikimediaReplicaClient.enabled?
      perform_with_replicas
    else
      Api::CheckNoCoordinatesJob.new.perform(*args)
    end
  end

  private

  def perform_with_replicas
    monuments = Monument.where("latitude IS NULL AND (photos_count > 0 OR with_photos = ?)", true).to_a
    return if monuments.empty?

    coords_by_item = WikimediaReplicaClient.fetch_gps_coordinates_for_monuments(monuments)
    monuments.each do |monument|
      coords = coords_by_item[monument.item]
      self.class.update_monument_coordinates!(monument, coords) if coords.present?
    end
  end
end
