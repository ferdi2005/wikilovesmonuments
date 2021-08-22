namespace :db do
    task :generate_csv => :environment do
        monuments = Monument.where(city: ENV["CITY"])
        csv = CSV.generate do |csv|
            csv << ["name", "description", "lat", "lon"]
            monuments.each do |monument|
                if monument.hidden
                    puts "No coordinates: #{monument.item} - #{monument.itemlabel}"
                    next
                end
                csv << [monument.itemlabel, monument.itemdescription, monument.latitude, monument.longitude]
            end
        end

        File.write("csv/#{ENV["CITY"]}.csv", csv, mode: "wt")
    end
end
