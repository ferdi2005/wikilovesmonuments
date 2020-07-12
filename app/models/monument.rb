class Monument < ApplicationRecord
  reverse_geocoded_by :latitude, :longitude

  def self.search(query = '')
    return where('itemlabel LIKE ? OR itemdescription LIKE ?', "%#{query.strip}%", "%#{query.strip}%")
  end
end
