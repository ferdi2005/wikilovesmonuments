class CheckNoCoordinatesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Monument.where("latitude IS NULL AND photos_count > 0").find_each do |monument|
      coordinates = []

      request = HTTParty.get("https://commons.wikimedia.org/w/api.php", query: { :action => :query, :prop => :imageinfo, :iiprop => "metadata", :iilimit => 500, generator: :search, gsrsearch: '"' + monument.wlmid + '"', gsrwhat: :text, gsrnamespace: 6, gsrlimit: 500, :format => :json}, uri_adapter: Addressable::URI).to_h
      
      metadata = request.try(:[], "query").try(:[], "pages")

      while !request["continue"].nil?
        request = HTTParty.get("https://commons.wikimedia.org/w/api.php", query: { :action => :query, :prop => :imageinfo, :iiprop => "metadata", :iilimit => 500, generator: :search, gsrsearch: '"' + monument.wlmid + '"', gcmcontinue: request["continue"]["gcmcontinue"], gsrwhat: :text, gsrnamespace: 6, gsrlimit: 500, :format => :json}, uri_adapter: Addressable::URI).to_h["query"]["pages"]

        metadata.merge!(request.try(:[], "query").try(:[], "pages")) # Unisce i due hash
      end

      next if metadata.blank?

      metadata.each do |_, image|
        latitude = image["imageinfo"][0]["metadata"].find { |h| h["name"] == "GPSLatitude" }.try(:[], "value").to_d
        
        longitude = image["imageinfo"][0]["metadata"].find { |h| h["name"] == "GPSLongitude" }.try(:[], "value").to_d

        if latitude != 0 && longitude != 0
          coordinates.push([latitude, longitude])
        end
      end

      geocenter = Geocoder::Calculations.geographic_center(coordinates)
      
      monument.update!(presumed_latitude: geocenter[0].truncate(5), presumed_longitude: geocenter[1].truncate(5)) unless geocenter[0].nan? || geocenter[1].nan?
    end
  end
end
