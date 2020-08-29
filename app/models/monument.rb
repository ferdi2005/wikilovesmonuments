class Monument < ApplicationRecord
  validates :item, uniqueness: true
  reverse_geocoded_by :latitude, :longitude

  def self.search(query = '')
    return where('lower(itemlabel) LIKE lower(?) OR lower(itemdescription) LIKE lower(?)', "%#{query.strip}%", "%#{query.strip}%")
  end
end
