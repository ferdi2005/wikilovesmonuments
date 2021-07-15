class Town < ApplicationRecord
    validates :name, uniqueness: true

    def self.search(query = '')
        where('lower(name) LIKE lower(?)', "#{query.strip}%")
    end    
end
