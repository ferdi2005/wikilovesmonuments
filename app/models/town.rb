class Town < ApplicationRecord
    validates :name, uniqueness: { scope: :disambiguation }
    reverse_geocoded_by :latitude, :longitude

    def self.search(query = '', locale = :en)
        if locale == :it
            where('lower(name) LIKE lower(?)', "#{query.strip}%")
        else
            where('lower(english_name) LIKE lower(?)', "#{query.strip}%")
        end
    end    
end
