# frozen_string_literal: true

class Monument < ApplicationRecord
  validates :item, uniqueness: true
  reverse_geocoded_by :latitude, :longitude

  def self.search(query = '')
    where('lower(itemlabel) LIKE lower(?) OR lower(itemdescription) LIKE lower(?)', "%#{query.strip}%", "%#{query.strip}%")
  end

  def commons_photos 
    return 'https://commons.wikimedia.org/w/index.php?search="' + self.wlmid + + '"'
  end
  def find_next_id
    selected = Monument.where(city: self.city).pluck(:wlmid).select { |id| id.match?(/^\d{2}[A-Z]\d{3}\d{4}$/)}
    unless selected.empty?
      nextid = selected.sort.last[6..10].to_i + 1
      newid = nextid.to_s.rjust(4, "0")
      freeid = "#{selected.sort.last[0..5]}#{newid}"
      if Monument.where(wlmid: freeid).any?
        return 0
      end
      return freeid
    else
      return 1
    end
  end
end
