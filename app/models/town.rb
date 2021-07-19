class Town < ApplicationRecord
    validates :name, uniqueness: { scope: :disambiguation }
    reverse_geocoded_by :latitude, :longitude

    def self.search(query = '')
        where('lower(name) LIKE lower(?)', "#{query.strip}%")
    end    
end
