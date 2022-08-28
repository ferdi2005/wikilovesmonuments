module MonumentsHelper
  include Pagy::Frontend
  def geocenter(monuments)
    return Geocoder::Calculations.geographic_center(monuments)  
  end

  def return_address(monument)
    if !monument.address.blank?
      return monument.address
    else
      return Geocoder.search([monument.latitude, monument.longitude])&.first&.address
    end
  end
end
