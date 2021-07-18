class Town < ApplicationRecord
    validates :name, uniqueness: { scope: :disambiguation }

    def self.search(query = '')
        where('lower(name) LIKE lower(?)', "#{query.strip}%")
    end    
end
