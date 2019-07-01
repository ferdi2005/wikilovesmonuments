module MonumentsHelper
  include Pagy::Frontend
  def geocenter(monuments)
    return Geocoder::Calculations.geographic_center(monuments)  
  end 
end
